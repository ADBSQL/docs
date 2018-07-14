### 辅助表开发文档

#### 1 场景描述

​        非分片键KV查询时，由于CN节点无法**精准确定**涉及节点，故而**全节点**下发查询。这样，导致**无关节点资源浪费**，例如，上海项目CPU飙升问题。目前，上海项目是通过**业务层构建辅助表来**解决因此而导致的CPU飙升问题。
​        业务侧希望能从数据库层面解决此问题，这也与之前AntDB微信群中一个同学的需求不谋而合，本文记录该功能开发原理和流程。
        目标：**期望查询变慢时，可通过构建辅助表提升查询性能**。

#### 2 辅助表原理

​        经过讨论，决定相仿业务层的方法，以**辅助表**的方式实现该功能。当非分片键的KV查询时，通过查询辅助表确定该查询涉及的节点，完成本次查询的精确下发。

#### 3 辅助表限制

- 只针对分片表的非分片键构建辅助表，**复制表、本地表、临时表不需要**。
- 只针对单表的非分片键等值查询，**非等值查询，多表关联暂不需要**。

#### 4 辅助表实现

##### 4-1  辅助表语法

- 创建辅助表
```sql
CREATE [UNLOGGED] AUXILIARY TABLE [auxiliary_table_name]
ON master_table_name ( column_name [ index_options ])
[ TABLESPACE tablespace_name ]
[ DISTRIBUTE BY OptDistributeType ]
[ TO NODE (node_name [, ...] ) | TO GROUP pgxcgroup_name ]

index_options:
/* empty */
| INDEX [ CONCURRENTLY ] [ name ] [ USING method ]
    [ WITH ( storage_parameter = value [, ... ] ) ]
    [ TABLESPACE tablespace_name ]

WARNING: 目前的语法还没有实现 index_options
```

> 说明：
> - AUXILIARY 为辅助表关键字
> - auxiliary_table_name 为辅助表表名，可选，若不指定则按照：主表名+辅助字段名+tbl 命名。
> - master_table_name 为主表表名，必选。
> - column_name 为主表字段名（需要建辅助表的字段），必选。
> - index_options 辅助表索引信息，指定时按照指定语法创建索引。未指定时，则按照默认参数创建索引。（辅助表的column_name字段必然创建索引。默认时，索引方法默认btree，命名空间与辅助表保持一致。）
> - tablespace_name 辅助表命名空间，可选。未指定时，为当前默认tablespace。
> - DISTRIBUTE BY OptDistributeType 辅助表分片方式，可选。未指定时，以辅助字段HASH分片。
> - TO NODE (node_name [, ...] ) | TO GROUP pgxcgroup_name 辅助表分片节点，可选。未指定时，默认ALL DATANODES。

```c
WITH INDEX opt_concurrently opt_index_name
			access_method_clause opt_reloptions OptTableSpace
				{
					IndexStmt *n = makeNode(IndexStmt);

					n->grammar = PARSE_GRAM_POSTGRES;
					n->unique = false;
					n->concurrent = $3;
					n->idxname = $4;
					n->accessMethod = $5;
					n->options = $6;
					n->tableSpace = NULL;
					n->whereClause = NULL;
					n->excludeOpNames = NIL;
					n->idxcomment = NULL;
					n->indexOid = InvalidOid;
					n->oldNode = InvalidOid;
					n->primary = false;
					n->isconstraint = false;
					n->deferrable = false;
					n->initdeferred = false;
					n->transformed = false;
					n->if_not_exists = false;

					/* set by caller */
					n->relation = NULL;
					n->indexParams = NIL;

					$$ = (Node *)n;
				}
		| 
```

##### 4-2 辅助表系统表

- pg_aux_class

```c
CATALOG(pg_aux_class,5320) BKI_WITHOUT_OIDS
{
	Oid		auxrelid;			/* Auxiliary table Oid */
	Oid		relid;				/* Parent table Oid */
	int16	attnum;				/* Auxiliary column number */
} FormData_pg_aux_class;

DECLARE_UNIQUE_INDEX(pg_aux_class_ident_index, 9019, on pg_aux_class using btree(auxrelid oid_ops));
#define AuxClassIdentIndexId  9019

DECLARE_UNIQUE_INDEX(pg_aux_class_relid_attnum_index, 9020, on pg_aux_class using btree(relid oid_ops, attnum int2_ops));
#define AuxClassRelidAttnumIndexId  9020
```

>说明:
>1. pg_aux_class 用于保存辅助表与主表及其辅助字段的关系，一张表可以构建多个辅助表。
>2. 主表的同一个字段只能创建一张辅助表。
>3. 目前默认辅助键只能有一个字段，不支持多字段创建辅助表。

##### 4-3 辅助表定义规则 

1. 辅助表的命名空间-namespace

   未指定时，默认当前命名空间。

2. 辅助表的命名规则

   未指定时，按照主表名+辅助字段名+aux命名。UNIQUE INDEX on (relid, attnum)意味着主表同一字段只能创建一张辅助表。

3. 辅助表为辅助字段自动创建索引

   辅助表的辅助字段，必然创建索引。未指定时，索引方法默认btree，命名空间默认当前命名空间。

##### 4-4 辅助表限制

1. 主表的同一个字段只能创建一张辅助表

   ```sql
   postgres=# create auxiliary table x_c2_aux2 on x(c2);
   ERROR:  duplicate key value violates unique constraint "pg_aux_class_relid_attnum_index"
   DETAIL:  Key (relid, attnum)=(294912, 2) already exists.
   Time: 7.402 ms
   ```

2. 辅助键目前仅支持一个字段。

3. INSERT/UPDATE/DELETE

   不能直接对辅助表进行DML操作，辅助表的DML操作由主表DML操作“级联”完成。

```sql
postgres=# insert into x_c2_aux (c2) values(101);
ERROR:  permission denied: "x_c2_aux" is an auxiliary table
HINT:  INSERT/UPDATE/DELETE on the auxiliary table can only be operated passively according to its main table
Time: 1.106 ms
postgres=# update x_c2_aux set c2 = 101 where c2 = 100;
ERROR:  permission denied: "x_c2_aux" is an auxiliary table
HINT:  INSERT/UPDATE/DELETE on the auxiliary table can only be operated passively according to its main table
Time: 0.511 ms
postgres=# delete from x_c2_aux where c2 = 100;
ERROR:  permission denied: "x_c2_aux" is an auxiliary table
HINT:  INSERT/UPDATE/DELETE on the auxiliary table can only be operated passively according to its main table
Time: 0.562 ms
```

2. TRUNCATE

   不能直接对辅助表进行TRUNCATE操作，辅助表会随着主表的TRUNCATE操作而TRUNCATE。

```sql
postgres=# truncate x_c2_aux ;
ERROR:  permission denied: "x_c2_aux" is an auxiliary table
Time: 1.030 ms
```

3. VACUUM操作
4. ALTER操作

- 不能直接对辅助表ALTER操作。

```sql
postgres=# alter table x_c2_aux add x int;
ERROR:  cannot ALTER TABLE "x_c2_aux" because it is an auxiliary table
Time: 12.117 ms
postgres=# alter table x_c2_aux drop c2;
ERROR:  cannot ALTER TABLE "x_c2_aux" because it is an auxiliary table
Time: 1.917 ms
postgres=# alter table x_c2_aux alter c2 set data type int8;
ERROR:  cannot ALTER TABLE "x_c2_aux" because it is an auxiliary table
Time: 1.839 ms
```

   - 当主表含有辅助表时，不能使用ALTER TABLE改变分片信息。

```sql
postgres=# alter table x distribute by hash(c3);
ERROR:  There are some auxiliary table(s) depend on "x"
HINT:  You should DROP its AUXILIARY TABLE(s) first
Time: 2.504 ms
```

   - ALTER TABLE作用于主表，改变分片范围（增加节点/删除节点/改变节点），辅表会自动重建。

```sql
postgres=# \d+ x
Table "public.x"
Column |  Type   | Modifiers | Storage | Stats target | Description 
--------+---------+-----------+---------+--------------+-------------
c1     | integer |           | plain   |              | 
c2     | integer |           | plain   |              | 
c3     | integer |           | plain   |              | 
c4     | integer |           | plain   |              | 
Auxiliary table:
"x_c2_aux" on x(c2)
"x_c3_aux" on x(c3)
"x_c4_aux" on x(c4)
Distribute By: HASH(c1)
Location Nodes: ALL DATANODES

postgres=# select xc_node_id,count(1) from x group by 1;                         
xc_node_id | count 
------------+-------
-560021589 |    42
352366662 |    58
(2 rows)

Time: 2.100 ms
postgres=# select auxnodeid,count(1) from x_c2_aux group by 1;                 
auxnodeid  | count 
------------+-------
-560021589 |    42
352366662 |    58
(2 rows)

Time: 2.277 ms
postgres=# alter table x to node(dn1);
ALTER TABLE
Time: 217.422 ms
postgres=# select xc_node_id,count(1) from x group by 1;
xc_node_id | count 
------------+-------
-560021589 |   100
(1 row)

Time: 123.344 ms
postgres=# select auxnodeid,count(1) from x_c2_aux group by 1;
auxnodeid  | count 
------------+-------
-560021589 |   100
(1 row)

Time: 2.539 ms
```

   - 不能使用ALTER TABLE DROP主表的辅助键，错误提示：有依赖对象。

```sql
postgres=# alter table x drop column c2;
ERROR:  cannot drop table x column c2 because other objects depend on it
DETAIL:  auxiliary table x_c2_aux depends on table x column c2
HINT:  Use DROP ... CASCADE to drop the dependent objects too.
Time: 3.375 ms
```

   - 不能使用ALTER TABLE SET TYPE改变辅助键的字段类型，错误提示：有依赖对象。

```sql
postgres=# alter table x alter c2 type varchar(10);
ERROR:  unexpected object depending on column: auxiliary table x_c2_aux
Time: 2.523 ms
```