# AntDB迁移：Oracle PL/SQL改写规则



> 本文仅供在 AntDB 的 Oracle 兼容模式下，将 Oracle 中 PL/SQL 代码修改为 AntDB 存储过程。



## Oracle兼容模式

### i. 实例级别

* **分布式版**

默认数据库语法为 `postgres` ，如果想全局使用 Oracle 语法，则可以在服务器级别设置语法参数。

1. 登录 adbmgr，设置所有 coordinator 的`grammar`参数：

```
postgres=# set coordinator all (grammar=oracle);
SET PARAM
postgres=# show cd1 grammar;
          type          | status |             message              
------------------------+--------+----------------------------------
 coordinator master cd1 | t      | debug_print_grammar = off       +
                        |        | grammar = oracle
(1 row)
```

2. 连接 Coordinator 节点，登录数据库，查看语法参数，并执行 Oracle 语法语句：

```
postgres=# show grammar ;
 grammar 
---------
 oracle
(1 row)

postgres=# select * from dual;
 DUMMY 
-------
 X
(1 row)
```



* **单机版**

在已经配置 PGDATA 环境变量的前提下，可通过如下方式修改实例的语法。未设置 PGDATA 则需要手动替换以下命令中的 $PGDATA 变量值。

1. 修改服务器参数：

```
vi $PGDATA/postgresql.conf
```

2. 添加语法参数：

```
grammar = oracle
```

3. 重载参数文件：

```
pg_ctl reload -D $PGDATA
```



### ii. 会话级别

如果没有进行服务器级别设置，默认登录数据库后的语法为 `postgres`。此时可在Session 级别切换到 Oracle 语法，即可执行 Oracle 语法下的 SQL 语句：

```
postgres=# set grammar to oracle;
SET
postgres=# show grammar ;
 grammar 
---------
 oracle
(1 row)

postgres=# select * from dual;
 DUMMY 
-------
 X
(1 row)
```



### iii. 语句级别

如果仅仅是某条 SQL 语句想使用 Oracle 语法，则可以用特殊 Hint 的方式指定语法（不依赖外部插件）：

```
postgres=# show grammar ;
 grammar  
----------
 postgres
(1 row)

postgres=# select * from dual;
ERROR:  relation "dual" does not exist
LINE 1: select * from dual;
                      ^
postgres=# /*ora*/ select * from dual;
 DUMMY 
-------
 X
(1 row)
```



## 1. 通用标准转换

### i. 关键词

Oracle PL/SQL 中在创建时的部分关键词，在 AntDB 中并不支持，需要统一去除。

**Oracle**:

```
-- Oracle 中有 editionable 和 authid current_user 语法
create or replace editionable procedure proc_test(p_id number) authid current_user 
as 
...
```

**AntDB**:

```
-- AntDB 中没有 editionable 和 authid current_user 语法
-- 在 DBeaver 中执行时，AntDB 存储过程体需要以 $$ 开头，并以 $$ 结尾
create or replace procedure proc_test(p_id number) 
as $$
...
$$;
```

**注意**： 

若在 DBeaver 中使用 AntDB 定制版 JDBC 驱动，则可去掉过程体前后的 $$ 标识。

建议使用 $$ 标识，便于存储过程创建报错时的报错点定位。



### ii. 数据类型转换

**必改**： 在兼容模式下，以下数据类型必须转换为对应的 AntDB 中的类型

```
NVARCHAR2        =>  varchar
NCHAR            =>  char
```

**可选**： 在原生模式下，以下数据类型建议修改为对应的 AntDB 中的类型

```
NVARCHAR2        =>  varchar
VARCHAR2         =>  varchar
NCHAR            =>  char
NUMBER           =>  numeric
DATE             =>  timestamp
LONG/LONG RAW/ROWID/UROWID/CLOB/NCLOB  =>  text
FLOAT(n)         =>  float
RAW(n)/BLOB      =>  bytea
*(n BYTE/CHAR)   =>  (n)
```



### iii. 大小写区别

在 Oracle PL/SQL 与 AntDB 存储过程中，命令语句均不区分大小写，但若在 Schema 名称，对象名称，以及字段名称前后使用双引号，则双引号内部的名称是大小写敏感的。

在大小写敏感的场景下，需要注意的是，Oracle中默认名称全为大写，AntDB中默认名称全为小写。

**Oracle**:

```
-- schema.table_name
"YWZC"."TEST_TABLE"
```

**AntDB**:

```
-- schema.table_name
"ywzc"."test_table"
```

建议不要对任何的Schema，表名，字段名上添加双引号，避免大小写敏感导致的报错。



## 2. 中文符号

在 Oracle PL/SQL 中，即使使用部分中文符号（包括：中文括号，中文逗号等）也能创建成功，在 AntDB 中则不能使用中文括号，需要将 Oracle PL/SQL 代码中所有的中文括号（全角括号），统一修改为对应的英文括号（半角括号）。



## 3. 无参数存储过程

若存储过程无需任何参数（包括输入参数和输出参数），在 Oracle PL/SQL 的声明中可以不使用括号，在 AntDB 中则必须使用空白括号。

**Oracle**:

```
create or replace function "incomecs"."who_am_i"
```

**AntDB**:

```
create or replace function "incomecs"."who_am_i"()
```



## 4. 布尔类型赋值

在 Oracle PL/SQL 与 AntDB 存储过程中，均支持 bool 类型，但二者的赋值方式有一定差异。

**Oracle**:

```
found_stack boolean default false
found_stack := true;
```

**AntDB**:

```
found_stack boolean default 'false'
found_stack := 'true';
```

**定位**： 可通过 boolean 关键词搜索需要修改的部分。



## 5. 自定义异常

在 Oracle PL/SQL 中，可以在声明时，定义自定义异常，AntDB中无需在声明过程中，指定自定义异常。所以在 Oracle PL/SQL 代码修改为 AntDB 存储过程时，需要去掉如下异常声明的代码。

**注意：集群版不支持存储过程内的异常处理。**

**Oracle**:

```
e_task_status_error           exception;
pragma exception_init(e_task_status_error, -20001);
```

**定位**： 可通过 exception 和 exception_init 关键词搜索需要修改的部分。



## 6. 自定义类型

在 Oracle PL/SQL 中，支持在存储过程的 declare 部分定义自定义类型，在 AntDB 中，自定义类型需要预先创建，然后在存储过程中直接使用。

**Oracle**:

```
-- Oracle 在存储过程内部定义
type t_record is record(id number, value number);
V_ITEM  t_record;
```

**AntDB**:

```
-- AntDB 需要在存储过程之外，预先创建好
CREATE TYPE t_record AS (id number, value number);

-- 存储过程中可直接使用预先创建的类型
CREATE OR REPLACE PROCEDURE TEST()
...
V_ITEM  t_record;
```

**定位**： 可通过 type 关键词搜索需要修改的部分。



## 7. 嵌套表修改

在 Oracle PL/SQL 与 AntDB 中，均可以定义并使用嵌套表，二者在定义时略有差异。

**Oracle**:

```
TYPE t_table IS TABLE OF t_record INDEX BY BINARY_INTEGER;
```

**AntDB**:

```
-- AntDB 需要在存储过程之外，预先创建好
CREATE TYPE xxx_t_record AS (id number, value number);

-- 存储过程中可直接使用预先创建的类型
TYPE t_table IS TABLE OF xxx_t_record;
```

**定位**： 可通过 table of 关键词搜索需要修改的部分。



## 8. 数组初始化

在 Oracle PL/SQL 中，自定义数组在声明时，即可通过构造函数进行初始化，在 AntDB 中不可在声明时初始化。

**Oracle**:

```
t_string_enery t_string_entry := t_string_entry('', '');
```

**AntDB**:

```
t_string_enery t_string_entry;
```

**定位**： 可通过 table of 关键词搜索需要修改的部分。



## 9. 绑定变量

在通过 execute immediate 执行动态 SQL 时，可以指定变量变量，在 Oracle PL/SQL 与 AntDB 中绑定变量占位符存在一定差异。

**Oracle**:

```
-- Oracle 中绑定变量使用名称占位
execute immediate 'select * from test where id = :id' using param1;
```

**AntDB**:

```
-- AntDB 中绑定变量，必须使用从 1 开始的占位符编号
execute immediate 'select * from test where id = $1' using param1;
```

**定位**： 可通过 execute immediate 关键词搜索需要修改的部分。



## 10. 数组取值

Oracle PL/SQL 与 AntDB 存储过程在使用数组的过程中，取值方式略有差异。

**Oracle**:

```
task_status_map(task_status_table(i).id) := task_status_table(i).value;
```

**AntDB**:

```
task_status_map[task_status_table[i].id] := task_status_table[i].value;
```



## 11. 自定义异常

Oracle PL/SQL 与 AntDB 中，关于自定义异常的触发，有如下差异。

**注意：集群版不支持存储过程内的异常处理。**

**Oracle**:

```
raise_application_error(-20001,'没有可以处理的表，请重新采集或传入要重跑的report_id','true');
```

**AntDB**:

```
-- 预先创建异常触发函数
create or replace function raise_application_error (pi_code text, pi_message text, pi_status boolean default 'true')
returns void
as $$
begin
  raise exception using errcode=pi_code, message=pi_message;
end;
$$ language plpgsql;

-- 调用异常触发函数
raise_application_error('O0001','没有可以处理的表，请重新采集或传入要重跑的report_id','true');
```

**定位**： 可通过 raise_application_error 关键词搜索需要修改的部分。



## 12. 异常处理

Oracle PL/SQL 与 AntDB 中，关于自定义异常的处理，有如下差异。

**注意：集群版不支持存储过程内的异常处理。**

**Oracle**:

```
-- 异常名称与触发时一致（异常名称绑定到指定的错误号）
when e_task_status_error then
```

**AntDB**:

```
-- 异常编号与触发时指定的编号一致
when sqlstate '20001' then
```

**定位**： 可通过 raise_application_error 关键词搜索需要修改的部分。



## 13. Merge 语句改写

Oracle PL/SQL 中支持 merge 语句，在 AntDB 存储过程中不支持，需要进行等效逻辑改写。

**Oracle**:

```
-- Merge 仅更新
merge into <TABLE_A>
using <TABLE_B>
   on <CONDITION>
 when matched then update set <UPDATE>;

-- 完整 Merge 语法
merge into <TABLE_A>
using <TABLE_B>
   on <CONDITION>
 when matched then update set <UPDATE>
 when not matched then insert (<INSERT_COLUMN>) values (<INSERT_VALUE>);
```

**AntDB**:

```
-- Merge 仅更新改写
update <TABLE_A>
   set <UPDATE>
  FROM <TABLE_B>
 WHERE <CONDITION>;

-- 完整 Merge 语法改写
/*pg*/ WITH upsert as (update <TABLE_A> set <UPDATE>
                  from <TABLE_B>
                 where <CONDITION_JOIN> RETURNING <TABLE_B>.*)
insert into <TABLE_A> (<INSERT_COLUMN>)
select <INSERT_VALUE> from <TABLE_B> where not exists (select 1 from upsert m where <CONDITION_B>);
```

**定位**： 可通过 merge 关键词搜索需要修改的部分。



## 14. 调用其他存储过程

在 Oracle PL/SQL 中，可以直接通过名称调用存储过程，在 AntDB 中则需要改为 PG 中的函数调用语法。

**Oracle**:

```
if v_count between 0800 and 2330  then
  ywzczx_mpz.sp_ywfz_ss_new;
end if;
```

**AntDB**:

```
-- 使用 select 调用函数，无参数的函数，需要加上空括号
if v_count between 0800 and 2330  then
  select ywzczx_mpz.sp_ywfz_ss_new();
end if;
```



## 15. DB Link 调用

在 Oracle PL/SQL 中可通过 DB Link 进行远程数据的读取和写入，在 AntDB 中建议不要进行跨库操作，若必须进行跨库操作，则可以使用 oracle_fdw 插件完成。

**Oracle**:

```
insert into tb_sndtmp@to_yx (smid,msg,tpa,smstype) values(...);
```

**AntDB**:

```
-- 以下替换写法中，fdw_tb_sndtmp 为远程表 tb_sndtmp 在 AntDB 中的映射 Schema
insert into fdw_tb_sndtmp.tb_sndtmp (smid,msg,tpa,smstype) values(...);
```

**定位**： 可通过 @ 字符搜索需要修改的部分。



## 16. 多行注释

在 Oracle PL/SQL 与 AntDB 存储过程中，均支持多行注释，但在以下情况下二者略有差异。

**Oracle**:

```
-- 在 /* 与 */ 之间包含了单个 /*，在 Oracle 中认为以下为一个注释
/*
this is comment 1
/*
this is comment 2
*/
```

**AntDB**:

```
-- AntDB 中会将以上注释认为缺少配对的 */ 注释结束符，所以需要修改为如下内容
/*
this is comment 1

this is comment 2
*/
```

**定位**： 可通过 /* 字符搜索需要修改的部分。



## 17. 忽略错误（子事务替代）

在存储过程中，发现部分如下逻辑，该逻辑中，在 execute immediate 中动态执行一条拼接出来的 SQL 语句，在遇到 SQL 报错时，忽略报错，并继续执行存储过程：

```
v_sql:='grant select on ywzc.'||v_table_log||v_toget_table||' to '||v_org_id;
begin
      execute immediate v_sql;
    exception
      when others then
        null;
    end;
```

在 AntDB 中，由于不支持集群版子事务，故可以采用如下命令替代以上命令，其中 execute_ignore_error 函数已经在数据库中预先创建：

```
v_sql:='grant select on ywzc.'||v_table_log||v_toget_table||' to '||v_org_id;
select execute_ignore_error(v_sql);   -- Oracle 兼容模式
perform execute_ignore_error(v_sql);   -- 原生模式
```



## 18. 对象差异

在 Oracle 与 AntDB 中，对象上的 DDL 语句也存在一定的差异。

### i. 建表语句

在存储过程中建表，需要注意不能携带 Oracle 特有的关键词和属性。

**Oracle**:

```
create table ywzc.temp_001 nologging
```

**AntDB**:

```
create table ywzc.temp_001
```

**定位**： 可通过 create table 字符搜索需要修改的部分。



### ii. 修改字段类型

修改字段类型的 SQL 从 Oracle 迁移到 AntDB 时，需要修改：

**Oracle**:

```
execute immediate 'alter table zq_skzx_jl modify ( pm char(10))';
```

**AntDB**:

```
execute immediate '/*ora*/ alter table zq_skzx_jl modify pm char(10)';
```



### iii. 创建索引

在 Oracle 与 AntDB 中创建索引存在一定的差异。Oracle 中创建索引可以指定 schema，但在 AntDB 中，索引必须与表创建在同一个 Schema 中，且不可指定 Schema，即使指定相同 Schema 也会导致语法报错。

**Oracle**:

```
CREATE INDEX CRM_CFGUSE.IDX_1325145 ON CRM_CFGUSE.OFFER_EXT_ATTR(OFFER_EXT_ATTR_ID);
```

**AntDB**:

```
CREATE INDEX IDX_1325145 ON CRM_CFGUSE.OFFER_EXT_ATTR(OFFER_EXT_ATTR_ID);
```

**定位**： 可通过 create index 字符搜索需要修改的部分。



### iii. 同义词

AntDB 中没有同义词概念，Oracle 中对表或视图创建的同义词，在 AntDB 中都可以统一使用视图替代。

**Oracle**:

```
v_sql:='create synonym '||v_org_id||'.'||v_toget_table||' for '||'ywzc.'||v_table_log||v_toget_table;
```

**AntDB**:

```
v_sql:='create view '||v_org_id||'.'||v_toget_table||' as select * from '||'ywzc.'||v_table_log||v_toget_table;
```

**定位**： 可通过 synonym 字符搜索需要修改的部分。



### iv. 视图

在 Oracle 中，创建视图可以指定 READ ONLY 关键词，在 AntDB 中则没有对应的关键词，视图的访问权限，可以在授权时指定。

**Oracle**:

```
v_sql:='create or replace  view  ywzc.'||v_table_log||v_toget_table||'   as   '||'  select  '||v_sql_columns||'  from  ';
v_sql:=v_sql||v_source_dis||'.'||v_source_table||v_source_suf||' '||v_sql_where||'   with  read  only';
```

**AntDB**:

```
v_sql:='create or replace  view  ywzc.'||v_table_log||v_toget_table||'   as   '||'  select  '||v_sql_columns||'  from  ';
v_sql:=v_sql||v_source_dis||'.'||v_source_table||v_source_suf||' '||v_sql_where;
```

**定位**： 可通过 view 字符搜索需要修改的部分。



## 19. AntDB原生函数修改

本地 Oracle 存储过程修改为 AntDB 中 Oracle 兼容模式的存储过程，并且在 AntDB 中创建成功之后，会在内部以 PostgreSQL 原生函数的形式保存，并可通过 PostgreSQL 标准的函数调用方式执行。

若从 AntDB 中获取到已经创建的存储过程代码，并在 dbeaver 中以 Oracle 兼容模式创建时，需要进行如下三个方面的修改。

* 将关键词 FUNCTION 修改为 PROCEDURE
* 添加空白括号，若存储过程或函数没有参数，那么需要在存储过程名之后补充一个空白的括号。
* 移除 PG 特有关键词，移除在存储过程体前面的 PG 函数特有关键词
* 添加 $$ 标识符（$$ 可以为任意的 $xxx$，只要保证存储过程代码体前后的 $xxx$ 完全一致即可）

从 AntDB 中获取到的代码：

```
CREATE OR REPLACE FUNCTION REPORT.LLBYH
  RETURNS void
  LANGUAGE plorasql
AS $function$
... (存储过程代码体)
END LLBYH $function$;
```

调整为 Oracle 模式下可执行的代码：

```
CREATE OR REPLACE PROCEDURE REPORT.LLBYH()
AS $function$
... (存储过程代码体)
END LLBYH $function$;
```



# 附录：常见错误处理

## 1. 更新分片字段

* 报错信息如下：

```
ERROR:  Partition column can't be updated in current version
```

该报错出现与对分片字段进行更新的情况。

AntDB 为分布式数据库，默认会按照如下规则依次选择分片键：

1. 若表中有主键，则选择主键作为分片字段
2. 若表中有唯一键，这选择唯一键作为分片字段
3. 选择建表的第一个字段作为分片字段

以上报错，说明 update 语句中， set 修改了分片字段，此时需要对表的分片方式进行调整，调整命令如下：

```
alter table dev_intelhome_pre distribute by hash(serv_id);
```

**注意**： 分片字段建议选择：数据均匀，非空且不会更新的字段。



## 2. FDW查询报错

* 报错信息如下：

```
[42704]: ERROR: user mapping not found for "ywzczx_wjb"”
```

该报错是因为当前用户下，未创建FDW远程服务器的登录信息。

可通过如下命令创建：

```
-- 以下命令创建对中转服务器的 fdw 访问用户信息，只需要创建一次即可，其中 ywzczx_wjb 为用户名
create user mapping if not exists FOR ywzczx_wjb SERVER srv_73_antdb options (user 'oracle', password '123Qwe!@#');
```



## 3. 权限报错

* 报错信息如下：

```
[42501]: ERROR: permission denied for schema fdw_crm_yj_order
```

该报错是因为当前用户，没有对 schema fdw_crm_yj_order 的访问权限，可通过如下方式授权：

```
-- 给用户 ywzczx_wjb 授予 fdw_crm_yj_order schema 上的所有权限
grant all on schema fdw_crm_yj_order to ywzczx_wjb;

-- 授予 schema 下表的读取权限
grant select on all tables in schema fdw_crm_yj_order to ywzczx_wjb；
```



## 4. 子事务报错

* 报错信息如下：

```
cannot assign XIDs in child transaction
```

该错误是由于在存储过程中使用了事务控制，AntDB分布式版本中不支持子事务，通常是由于在存储过程中带有如下语句导致：

* commit;
* rollback;
* execute immediate 'commit';
* execute immediate 'rollback';
* begin ... exception ... end;

需要将存储过程中的事务控制语句删除掉，对于忽略动态SQL的报错，可使用如下语句替代：

```
select execute_ignore_error(v_sql);   -- Oracle 兼容模式，其中 v_sql 为动态执行的 SQL 语句
```



## 5. UPDATE 语句报错

* 报错信息如下：

```
[0A000]: ERROR: cluster reduce not support from REPLICATED to none REPLICATED
```

该错误时由于执行如下 update 更新语句导致：

```
UPDATE point_day_subst_rpt_2020 a
SET a.pm_all=
  (SELECT bb.pm_day2
   FROM
     (SELECT b.tj_date,
             b.branch_name,
             rank() over(partition BY tj_date,fdyf
                         ORDER BY b.rate_all DESC) pm_day2
      FROM point_day_subst_rpt_2020 b
      WHERE b. subst_name NOT in('政企部','政企合计', '全市合计')
        AND b.tj_date>='20200823') bb
   WHERE bb.branch_name=a.branch_name
     AND bb.tj_date=a.tj_date)
WHERE subst_name NOT in('政企部','政企合计', '全市合计')
  AND a.tj_date>='20200823'
```

类似这种 update 语句，在分布式版本中，可修改为如下语法：

```
UPDATE point_day_subst_rpt_2020 a
  SET pm_all = bb.pm_day2
  from (SELECT b.tj_date, b.branch_name
             , rank() over(partition BY tj_date,fdyf ORDER BY b.rate_all DESC) pm_day2
            FROM point_day_subst_rpt_2020 b
            WHERE b.subst_name NOT in ('政企部','政企合计', '全市合计')
              AND b.tj_date>='20200823') bb
 WHERE a.subst_name NOT in ('政企部','政企合计', '全市合计')
   AND a.tj_date>='20200823'
   AND bb.branch_name=a.branch_name
   AND bb.tj_date=a.tj_date
```



## 6. NVL函数报错

* 报错信息如下：

```
[42883]: ERROR: function oracle.nvl(text, oracle.varchar2) does not exist
```

在 create table xxx as select ... 语法情况下，若 select 语句中有 nvl 函数，可能会有上面的报错。

对于此类报错，可以使用 coalesce 函数代替 nvl 函数，二者使用方式基本一致。或者直接对启用语句级 Oracle 兼容。

```
-- 将如下函数：
select nvl('xxx', 'xxx') from dual;
-- 修改为：
select coalesce('xxx', 'xxx') from dual;
-- 或启用 Oracle 兼容
/*ora*/ select nvl('xxx', 'xxx') from dual;
```



## 7. to_char(sysdate)函数报错

* 报错信息如下：

```
ERROR: could not open relation with OID 0
```

在部分使用 to_char(sysdate) 函数的查询语句中，可能会遇到上述错误。

对于此类报错，可使用 clock_timestamp() 函数代替 sysdate，改写方式如下：

```
select to_char(clock_timestamp())
```



## 8. 动态语句报错

* 报错信息如下：

```
ERROR: operator is not unique: oracle.varchar2 = integer
ERROR: function decode(text, unknown, unknown, unknown) does not exist
```

在动态执行的场景下，可能会遇到一些操作符或者函数不存在的报错，这是因为在动态执行的 SQL 中，没有启用 Oracle 兼容模式，可使用如下方式，对动态执行的 SQL 启用 Oracle 兼容模式。

```
/*ora*/ select * from xxx;
/*ora*/ create table xxx as select * from xxx;
```



## 9. 整形越界

* 报错信息如下：

```
ERROR:  integer out of range
```

该报错是由于往整形中插入的数字，超过了整形的最大限制，可以将对应的字段类型调整为 bigint 或者 numeric 类型。

以下为一则修改示例：

```
-- 默认情况下，直接写的数字默认都是 int 类型
V_SQL:='/*ora*/ CREATE TABLE  YWZCZX_GHD.GHD_ZQ_MON_1_BILL  AS  SELECT 0 SUM_MONTH, 0 SERV_ID, 0 SERV_ID2, 0 CHARGE  FROM DUAL WHERE 1<>1 ';

-- 以上命令创建的表中，字段类型都是 int
yj_db=# \d ywzczx_ghd.ghd_zq_mon_1_bill 
         Table "ywzczx_ghd.ghd_zq_mon_1_bill"
  Column   |  Type   | Collation | Nullable | Default 
-----------+---------+-----------+----------+---------
 sum_month | integer |           |          | 
 serv_id   | integer |           |          | 
 serv_id2  | integer |           |          | 
 charge    | integer |           |          | 
Indexes:
    "a_zqcharge1" btree (serv_id)
    "a_zqcharge2" btree (serv_id2)

-- 后续往这张表中插入超过 int 最大限制的数字，就回报错
-- 可以在创建的时候，指定类型为 bigint 或者 numeric，避免后续插入报错
V_SQL:='/*ora*/  CREATE TABLE  YWZCZX_GHD.GHD_ZQ_MON_1_BILL  AS  SELECT 0::bigint SUM_MONTH,0::bigint SERV_ID ,0::bigint  SERV_ID2,0::bigint  CHARGE  FROM DUAL WHERE 1<>1 ';
```



## 10. Group by 常量数字报错

* 报错信息如下：

```
ERROR:  GROUP BY position 202006 is not in select list
```

此报错是因为：在 group by 语句中，不能出现常量数字。

报错 SQL 如下：

```
/*ora*/SELECT 202006 SUM_MONTH,
              TO_NUMBER(SERV_ID) SERV_ID,
              TO_NUMBER(SERV_ID) SERV_ID2,
              SUM(CHARGE-TAX_CHARGE)/100 CHARGE
FROM EDA_YJ.KH_NBR_OUTPUT_202006
WHERE IS_FILTER=0
GROUP BY 202006,
         TO_NUMBER(SERV_ID) ,
         TO_NUMBER(SERV_ID);
```

对应的正常 SQL 如下：

```
/*ora*/SELECT 202006 SUM_MONTH,
              TO_NUMBER(SERV_ID) SERV_ID,
              TO_NUMBER(SERV_ID) SERV_ID2,
              SUM(CHARGE-TAX_CHARGE)/100 CHARGE
FROM EDA_YJ.KH_NBR_OUTPUT_202006
WHERE IS_FILTER=0
GROUP BY TO_NUMBER(SERV_ID) ,
         TO_NUMBER(SERV_ID);
```



## 11. Round(varchar2) 不唯一

* 报错信息如下：

```
ERROR:  function round(varchar2) is not unique
LINE 2: round(avg_xx_varchar2) avg_xx
              ^
HINT:  Could not choose a best candidate function. You might need to add explicit type casts.
```

这是由于 round 函数中，传入的字段类型是 varchar2 类型，需要明确指定将 varchar2 转换为 numeric 类型。

**修改前**：

```
select round(avg_xx_varchar2) avg_xx
```

**修改后**：

```
select round(avg_xx_varchar2::numeric) avg_xx
```





