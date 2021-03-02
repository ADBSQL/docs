
# 全局视图相关说明

通过 execute direct + pgxc_node 表，实现全局视图访问。


## 相关脚本

```
Global_Views.sql
```

目前脚本中实现了 gv_locks/gv_stat_activity/gv_blocking_session/gv_blocking_session_brief/gv_stat_all_tables 五个全局视图。
其中：
    * gv_locks 中特殊定制，将 relation 字段从 oid 转换为对应的对象名称
    * gv_stat_activity 直接原字段对应于各个节点上的 pg_stat_activity 视图
    * gv_blocking_session 为基于 gv_stat_activity 和 gv_locks 视图关联分析得到的进程之间的相互阻塞关系
    * gv_blocking_session_brief 为 gv_blocking_session 视图的部分字段精简，便于直接查看
    * gv_stat_all_tables 为对所有 coordinator 节点的 pg_stat_all_tables 信息汇总

若有其他全局视图需求，可参照这些视图的创建方式进行额外创建。


## 注意事项

1. 需要使用超级用户登录 (用于执行 execute direct)
2. 目前全局视图查询了 pgxc_node 中记录的所有 Coordinator 和 Datanode 节点
3. 全局视图增加和节点信息相关的 3 个字段： node_oid, node_name, node_type


## 使用方式

1. 使用超级用户登录 postgres 库（或其他库），运行创建脚本：

```shell
psql -U antdb -h localhost -d postgres -f Global_Views.sql
```

2. 查看全局视图

```sql
postgres=# \dv gv*
              List of relations
 Schema |        Name        | Type | Owner  
--------+--------------------+------+--------
 public | gv_locks           | view | hongye
 public | gv_stat_activity   | view | hongye
 public | gv_stat_all_tables | view | hongye
```

3. 使用全局视图

```sql
postgres=# select * from gv_Locks;
 node_oid | node_name | node_type |  locktype  | database | relation | page | tuple | virtualxid | transactionid | classid | objid | objsubid | virtualtransaction |  pid  |      mode       | granted | fastpath 
----------+-----------+-----------+------------+----------+----------+------+-------+------------+---------------+---------+-------+----------+--------------------+-------+-----------------+---------+----------
    11861 | cm_1      | C         | relation   |    13522 |    11717 |      |       |            |               |         |       |          | 3/22895            | 31092 | AccessShareLock | t       | t
    11861 | cm_1      | C         | virtualxid |          |          |      |       | 3/22895    |               |         |       |          | 3/22895            | 31092 | ExclusiveLock   | t       | t
    11861 | cm_1      | C         | relation   |    13522 |    49503 |      |       |            |               |         |       |          | 2/336626           | 30525 | AccessShareLock | t       | t
    11861 | cm_1      | C         | relation   |    13522 |     1259 |      |       |            |               |         |       |          | 2/336626           | 30525 | AccessShareLock | t       | t
    11861 | cm_1      | C         | relation   |    13522 |     2615 |      |       |            |               |         |       |          | 2/336626           | 30525 | AccessShareLock | t       | t
    11861 | cm_1      | C         | relation   |    13522 |      549 |      |       |            |               |         |       |          | 2/336626           | 30525 | AccessShareLock | t       | t
    11861 | cm_1      | C         | relation   |    13522 |      113 |      |       |            |               |         |       |          | 2/336626           | 30525 | AccessShareLock | t       | t
    11861 | cm_1      | C         | relation   |    13522 |     1417 |      |       |            |               |         |       |          | 2/336626           | 30525 | AccessShareLock | t       | t
    11861 | cm_1      | C         | relation   |    13522 |    49285 |      |       |            |               |         |       |          | 2/336626           | 30525 | AccessShareLock | t       | t
    11861 | cm_1      | C         | virtualxid |          |          |      |       | 2/336626   |               |         |       |          | 2/336626           | 30525 | ExclusiveLock   | t       | t
    11861 | cm_1      | C         | advisory   |    13522 |          |      |       |            |               |   65535 | 65535 |        2 | 3/22895            | 31092 | ShareLock       | t       | f
    11861 | cm_1      | C         | relation   |        0 |     9015 |      |       |            |               |         |       |          | 2/336626           | 30525 | AccessShareLock | t       | f
    16384 | cm_2      | C         | relation   |    13522 |    11717 |      |       |            |               |         |       |          | 3/1568             | 31097 | AccessShareLock | t       | t
    16384 | cm_2      | C         | virtualxid |          |          |      |       | 3/1568     |               |         |       |          | 3/1568             | 31097 | ExclusiveLock   | t       | t
    16384 | cm_2      | C         | advisory   |    13522 |          |      |       |            |               |   65535 | 65535 |        2 | 3/1568             | 31097 | ShareLock       | t       | f
    16385 | dm_1      | D         | relation   |    13522 |    11717 |      |       |            |               |         |       |          | 3/472441           | 31128 | AccessShareLock | t       | t
    16385 | dm_1      | D         | virtualxid |          |          |      |       | 3/472441   |               |         |       |          | 3/472441           | 31128 | ExclusiveLock   | t       | t
    16386 | dm_2      | D         | relation   |    13522 |    11717 |      |       |            |               |         |       |          | 3/1570             | 31136 | AccessShareLock | t       | t
    16386 | dm_2      | D         | virtualxid |          |          |      |       | 3/1570     |               |         |       |          | 3/1570             | 31136 | ExclusiveLock   | t       | t
(19 rows)
postgres=# 
postgres=# select * from gv_blocking_session_brief;
 run_node_pid | run_user | run_wait_event | run_application |     run_query      | relation | wait_node_pid | wait_user | wait_application |                 wait_query                 
--------------+----------+----------------+-----------------+--------------------+----------+---------------+-----------+------------------+--------------------------------------------
 gc_m:46583   | hongye   |                | psql@127.0.0.1  | delete from test2; |          | gc_m:182907   | hongye    | psql@127.0.0.1   | delete from test4;
 gc_m:46639   | hongye   |                | psql@127.0.0.1  | delete from test1; |          | gc_m:46694    | hongye    | psql@127.0.0.1   | create table test6 as select * from test2;
 gc_m:46530   | hongye   |                | psql@127.0.0.1  | delete from test1; | test1    | gc_m:46639    | hongye    | psql@127.0.0.1   | delete from test1;
 gc_m:46453   | hongye   | ClientRead     | psql@127.0.0.1  | delete from test1; |          | gc_m:46530    | hongye    | psql@127.0.0.1   | delete from test1;
 gc_m:46530   | hongye   |                | psql@127.0.0.1  | delete from test1; |          | gc_m:46583    | hongye    | psql@127.0.0.1   | delete from test2;
(5 rows)
```
