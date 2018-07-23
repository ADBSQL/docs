# AntDB辅助索引表简单使用说明

## 使用场景
很多分布式场景下，一个分片字段并不能满足所有的场景。

比如历史业务账单按用户ID来分片很适合做用户统计，但还有一些情况需要按订单号查询。这种情况下为了找到一个订单对应的记录，因为不知这条记录在哪个节点上，所以则需要全节点扫描。这里就无法体现分布式的优点，造成资源浪费（有效工作节点只有一个），特别是在高并发时，就很可能会造成CPU不够用。

基于这种情况，AntDB的辅助表功能可以有效的应对。
### 原理
假如有表t1(a,b,c,...)，a为分片列,b为上面场景中的“订单”列。
1. 针对非分片列b增加一张辅助索引表。辅助索引表的分片列为b，和非分片字段a，所有的数据都与主表t1保持同步。
2. 如果查询t1表时包含的过滤条件中有“b=xxx”这样的表达式，则把xxx带入到对应的辅助索引表中，查询出列a的值所在的节点。
3. 修改执行计划，只在上一步查找出的节点上执行查询。

最终的执行时间分三种情况：
* 一般情况：本需要全节点扫描的查询，现在只需要在两个节点上扫描。单次查询时间变长，高并发查询时间变短。
* 最优情况：第二步查询不到符合条件的数据，则不需要再扫描主表。单次查询时间不变，高并发查询时间变短。
* 最坏情况：第二步查到的数据在所有节点上，仍需要全节点扫描主表。单次查询时间变长，高并发查询时间变长。

所以创建辅助索引表和创建索引相同，要找那些重复率低的列。否则最终反而会使查询时间变长。

因为有辅助表的存在，主表数据的更新操作会变的更慢（主表数据更新时会同步更新辅助表）。
## 用例
### 创建主表
```sql
create table test(id int, name text, age int) distribute by hash(id);
```
### 在 _name_ 上创建辅助索引

```sql
create auxiliary table on test(name);
\d+ test
```
```
                         Table "public.test"
 Column |  Type   | Modifiers | Storage  | Stats target | Description 
--------+---------+-----------+----------+--------------+-------------
 id     | integer |           | plain    |              | 
 name   | text    |           | extended |              | 
 age    | integer |           | plain    |              | 
Auxiliary table:
    "test_name_aux" on test(name)
Distribute By: HASH(id)
Location Nodes: ALL DATANODES
```
### 在主表test上插入一些数据

```sql
insert into test select n,'name'||n,random()*100 from generate_series(1,10) as n;
select *,adb_node_oid() as node from test;
```
```
 id |  name  | age | node  
----+--------+-----+-------
 14 | name14 |  12 | 16385
 15 | name15 |  46 | 16385
 20 | name20 |  46 | 16385
 11 | name11 |  81 | 16386
 12 | name12 |   9 | 16386
 17 | name17 |  15 | 16386
 18 | name18 |  37 | 16386
 19 | name19 |  98 | 16386
 10 | name10 |   3 | 16387
 13 | name13 |  25 | 16387
 16 | name16 |  73 | 16387
(11 rows)
```
### 非分片字段等值执行计划

```sql
--查询结果
select * from test where name='name12';
 id |  name  | age 
----+--------+-----
 12 | name12 |   9
(1 row)

--执行计划：name为非分片字段,最终执行计划只在16386这个节点上执行
explain (verbose,analyze,costs off,timing off) select * from test where name='name12';
                      QUERY PLAN                       
-------------------------------------------------------
 Cluster Gather (actual rows=1 loops=1)
   Remote node: 16386
   ->  Seq Scan on public.test (actual rows=0 loops=1)
         Output: id, name, age
         Filter: (test.name = 'name12'::text)
         Remote node: 16386
         Node 16386: (actual rows=1 loops=1)
 Planning time: 15.222 ms
 Execution time: 0.433 ms
(9 rows)

--关闭使用辅助表功能后的执行计划
set use_aux_type =off;
explain (verbose,analyze,costs off,timing off) select * from test where name='name12';
                      QUERY PLAN                       
-------------------------------------------------------
 Cluster Gather (actual rows=1 loops=1)
   Remote node: 16385,16386,16387
   ->  Seq Scan on public.test (actual rows=0 loops=1)
         Output: id, name, age
         Filter: (test.name = 'name12'::text)
         Remote node: 16385,16386,16387
         Node 16385: (actual rows=0 loops=1)
         Node 16386: (actual rows=1 loops=1)
         Node 16387: (actual rows=0 loops=1)
 Planning time: 0.331 ms
 Execution time: 1.743 ms
(11 rows)

--对in表达式同样支持,两条记录在同一个节点上
set use_aux_types =on;
explain (verbose,analyze,costs off,timing off) select * from test where name in('name12','name17');
                          QUERY PLAN                           
---------------------------------------------------------------
 Cluster Gather (actual rows=2 loops=1)
   Remote node: 16386
   ->  Seq Scan on public.test (actual rows=0 loops=1)
         Output: id, name, age
         Filter: (test.name = ANY ('{name12,name17}'::text[]))
         Remote node: 16386
         Node 16386: (actual rows=2 loops=1)
 Planning time: 204.687 ms
 Execution time: 0.365 ms
(9 rows)

--两条记录在两个不同节点上
explain (verbose,analyze,costs off,timing off) select * from test where name in('name12','name16');
                          QUERY PLAN                           
---------------------------------------------------------------
 Cluster Gather (actual rows=2 loops=1)
   Remote node: 16386,16387
   ->  Seq Scan on public.test (actual rows=0 loops=1)
         Output: id, name, age
         Filter: (test.name = ANY ('{name12,name16}'::text[]))
         Remote node: 16386,16387
         Node 16386: (actual rows=1 loops=1)
         Node 16387: (actual rows=1 loops=1)
 Planning time: 104.125 ms
 Execution time: 0.409 ms
(10 rows)
```

## 创建辅助索引表的语法为

CREATE AUXILIARY TABLE [*aux_name*] ON *table_name*(*column*);
