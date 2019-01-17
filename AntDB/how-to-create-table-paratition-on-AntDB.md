# AntDB4.0 分区表使用说明

***
本文主要探讨如何在AntDB4.0 使用分区表。

通过本文阐述下列功能：
* AntDB 分区表介绍
* AntDB 分区、分片的区别
* AntDB 分区表的创建/使用
* 其他注意事项
***
## AntDB 分区表
AntDB4.0的分区表依旧使用了继承的特性，但不需要手工写存储过程和触发器了。

在使用方面，我们需要先创建主表，然后创建分区（即子表）。

目前支持list、range分区。

## AntDB 分区、分片的区别
* 分区，局限于单一数据节点，将一张表分散存储在不同的物理块中。

![AntDB分区](https://github.com/greatebee/AntDB/blob/master/pic/partition_1.png)

* 分片，分片就是分库，属于水平切分，将一张表按照某种规则放到多个数据节点中。

![AntDB分片](https://github.com/greatebee/AntDB/blob/master/pic/partition_2.png)

分片和分区不冲突。
## 如何创建分区表
### list分区
1. 创建主分区

按areacode字段水平分片切分到多个数据节点，单个数据节点按month字段设置list分区进行逻辑切分
```shell
create table p_list (
areacode varchar(10),
month varchar(10),
id int
) 
partition by list (month) 
distribute by hash(areacode);
```
2. 创建子分区

每月的数据按指定规则落入不同的分区子表
```shell
create table p_list_201801 partition of p_list FOR VALUES in ( '201801' );
create table p_list_201802 partition of p_list FOR VALUES in ( '201802' );
```

3. 验证分区表是否创建成功

存在2个子表
```shell
\d+ p_list
                                           Table "public.p_list"
  Column  |         Type          | Collation | Nullable | Default | Storage  | Stats target | Description 
----------+-----------------------+-----------+----------+---------+----------+--------------+-------------
 areacode | character varying(10) |           |          |         | extended |              | 
 month    | character varying(10) |           |          |         | extended |              | 
 id       | integer               |           |          |         | plain    |              | 
Partition key: LIST (month)
Partitions: p_list_201801 FOR VALUES IN ('201801'),
            p_list_201802 FOR VALUES IN ('201802')
Distribute By: HASH(areacode)
Location Nodes: ALL DATANODES
```
4. 插入数据

不同的区号+月份的数据，落入对应的分区子表
```shell
insert into p_list select '0513','201801',id from generate_series(1, 800) id;
insert into p_list select '0513','201802',id from generate_series(1, 850) id;
insert into p_list select '0512','201801',id from generate_series(1, 1000) id;
insert into p_list select '0512','201802',id from generate_series(1, 1200) id;
```

5. 验证数据分片是否正确

0513的数据全部落入db1_1节点，总数 1650；

0512的数据全部落入db2_1节点，总数 2200.

```shell
select node_name, count(*)                                                 
from p_list a, pgxc_node b 
where a.xc_node_id=b.node_id and node_type='D' group by node_name order by node_name asc; 
 node_name | count 
-----------+-------
 db1_1     |  1650
 db2_1     |  2200
(2 rows)
```

6. 验证数据分片分区是否正确

数据分片分区正常
```shell
select b.node_name,a.tableoid::regclass,count(*) 
from p_list a,pgxc_node b 
where a.xc_node_id=b.node_id and b.node_type='D' 
group by b.node_name,a.tableoid::regclass;
 node_name |   tableoid    | count 
-----------+---------------+-------
 db1_1     | p_list_201801 |   800
 db1_1     | p_list_201802 |   850
 db2_1     | p_list_201801 |  1000
 db2_1     | p_list_201802 |  1200
(4 rows)
```

### range分区
1. 创建主分区

按areacode字段水平分片切分到多个数据节点，单个数据节点按id字段设置range分区进行逻辑切分
```shell
create table p_range (
areacode varchar(10),
month varchar(10),
id int
) 
partition by range (id) 
distribute by hash(areacode);
```
2. 创建子分区

指定id范围的数据按指定规则落入不同的分区子表
```shell
create table p_range_500 partition of p_range FOR VALUES from (1) to (500);
create table p_range_1000 partition of p_range FOR VALUES from (500) to (1000);
```
**Range分区范围为 >= 最小值 and < 最大值。**
**务必注意上述range分区表中间值的设置。**

3. 验证分区表是否创建成功

存在2个子表
```shell
\d+ p_range
                                          Table "public.p_range"
  Column  |         Type          | Collation | Nullable | Default | Storage  | Stats target | Description 
----------+-----------------------+-----------+----------+---------+----------+--------------+-------------
 areacode | character varying(10) |           |          |         | extended |              | 
 month    | character varying(10) |           |          |         | extended |              | 
 id       | integer               |           |          |         | plain    |              | 
Partition key: RANGE (id)
Partitions: p_range_1000 FOR VALUES FROM (501) TO (1000),
            p_range_500 FOR VALUES FROM (1) TO (500)
Distribute By: HASH(areacode)
Location Nodes: ALL DATANODES
```
4. 插入数据

不同的区号+id的数据，落入对应的分区子表
```shell
insert into p_range select '0513','201801',id from generate_series(1, 800) id;
insert into p_range select '0513','201802',id from generate_series(1, 850) id;
insert into p_range select '0512','201801',id from generate_series(1, 900) id;
insert into p_range select '0512','201802',id from generate_series(1, 950) id;
```

5. 验证数据分片是否正确

0513的数据全部落入db1_1节点，总数 1650；

0512的数据全部落入db2_1节点，总数 1850.

```shell
select node_name, count(*)                                                 
from p_range a, pgxc_node b 
where a.xc_node_id=b.node_id and node_type='D' group by node_name order by node_name asc; 
 node_name | count 
-----------+-------
 db1_1     |  1650
 db2_1     |  1850
(2 rows)
```

6. 验证数据分片分区是否正确

数据分片分区正常
```shell
select b.node_name,a.tableoid::regclass,count(*) 
from p_range a,pgxc_node b 
where a.xc_node_id=b.node_id and b.node_type='D' 
group by b.node_name,a.tableoid::regclass;
 node_name |   tableoid   | count 
-----------+--------------+-------
 db1_1     | p_range_500  |   998
 db1_1     | p_range_1000 |   652
 db2_1     | p_range_500  |   998
 db2_1     | p_range_1000 |   852
(4 rows)
```

## 其他注意事项
* 建立分区表时必需指定主表。
* 分区表和主表的 列数量、定义 必须完全一致。
* 分区表的列可以单独增加Default值，或约束。
* 当用户向主表插入数据库时，系统自动路由到对应的分区，如果没有找到对应分区，则抛出错误。
* 指定分区约束的值（范围，LIST值），范围，LIST不能重叠，重叠的路由会卡壳。
* 指定分区的列必需设置成not null,如建立主表时没设置系统会自动加上。
* Range分区范围为 >=最小值 and <最大值……
* 不支持通过更新的方法把数据从一个区移动到另外一个区，这样做会报错。
    
  如果要这样做的话需要删除原来的记录，再INSERT一条新的记录。
* 修改主表的字段名，字段类型时，会自动同时修改所有的分区。
* TRUNCATE 主表时，会清除所有继承表分区的记录，如果要清除单个分区，请对分区进行操作。
* DROP主表时会把所有子表一起给DROP掉，如果drop单个分区，请对分区进行操作。
* 使用psql能查看分区表的详细定义。
