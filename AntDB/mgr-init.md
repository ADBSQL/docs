# adbmgr 初始化操作
#### 背景
在部分版本替换的场景中，如果adbmgr新增了功能，因为对mgr的系统表做了修改，所以需要对adbmgr进行初始化操作。   
比如，在某个版本中，新增了显示节点物理大小的命令，在直接替换版本后，无法使用这个命令：    

```sql
postgres=# list node size all;
ERROR:  function mgr_list_nodesize_all(boolean) does not exist
HINT:  No function matches the given name and argument types. You might need to add explicit type casts.
```

注意：**数据库集群不需要初始化**。
#### 操作步骤
##### 导出mgr侧相关表

AntDB提供了 `mgr_dump` 工具来导出mgr中用到的表。    
导出mgr侧表的命令如下：
```shell
mgr_dump -p 16432 -d postgres --mgr_table -f mgr_tab.sql
```
其中：   
* -p 的参数需要修改为实际环境端口
* -f 的参数需要修改为实际操作的文件名


##### 导出monitor 相关表
adbmgr内置了一些job，用于采集主机、节点的相关性能指标，如果开启了job，也需要将job的采集结果数据导出。    
检查是否开启job,登陆adbmgr：    
```sql
postgres=# list job;
 joboid |      name       |           nexttime            | interval | status |                  command                   | description 
--------+-----------------+-------------------------------+----------+--------+--------------------------------------------+-------------
  16399 | slowlog_for_adb | 2019-01-29 17:29:59.369626+08 |       60 | t      | select monitor_slowlog_insert_data();      | 
  16398 | tps_for_adb     | 2019-01-29 17:29:59.373206+08 |       60 | t      | select monitor_databasetps_insert_data();  | 
  16397 | usage_for_adb   | 2019-01-29 17:29:59.367332+08 |       60 | t      | select monitor_databaseitem_insert_data(); | 
  16396 | usage_for_host  | 2019-01-29 17:29:59.374407+08 |       60 | t      | select monitor_get_hostinfo();             | 
(4 rows)
```
如果，`list job` 返回结果为空，则说明没有开启job，这个步骤可以跳过。    
如果返回结果，但是 `status` 为f， 则也建议导出monitor数据。    
执行导出命令：
```shell
mgr_dump "port=16432 dbname=postgres options='-c command_mode=sql'" -t 'monitor_*' -a -f monitor_data.sql
```
如果存在的monitor比较多，导出需要花费些时间。

##### adbmgr 初始化
数据导出完成后，停止adbmgr，准备初始化操作。    
停止adbmgr：
```shell
mgr_ctl stop -D /data/danghb//data/adb40/d1/mgr -m fast
```
如果有mgr slave，记得要把slave也停掉。   
初始化adbmgr,初始化之前最好先备份下：
```shell
# 备份mgr数据目录
cp -R /data/danghb//data/adb40/d1/mgr /data/danghb//data/adb40/d1/mgr_190130
# 清空mgr数据目录
rm -rf /data/danghb//data/adb40/d1/mgr
# 初始化mgr
initmgr -D /data/danghb//data/adb40/d1/mgr
# 恢复mgr的配置文件
cp /data/danghb//data/adb40/d1/mgr_190130/postgresql.conf /data/danghb//data/adb40/d1/mgr/postgresql.conf 
cp /data/danghb//data/adb40/d1/mgr_190130/pg_hba.conf /data/danghb//data/adb40/d1/mgr/pg_hba.conf 
# 启动mgr
mgr_ctl start -D /data/danghb//data/adb40/d1/mgr
```
此时查看节点信息，都是空的：
```
postgres=# list node;
 name | host | type | mastername | port | sync_state | path | initialized | incluster | readonly 
------+------+------+------------+------+------------+------+-------------+-----------+----------
(0 rows)
```

##### 导入mgr侧数据
进入之前mgr_dump 出来的文件所在目录，执行导入操作：
```
psql -p 16432 -d postgres -f mgr_tab.sql
```
`already exists` 类型的错误可以忽略。

##### 导入monitor数据
进入之前mgr_dump 出来的文件所在目录，执行导入操作：
```
psql "port=16432 dbname=postgres options='-c command_mode=sql'" -f monitor_data.sql
```
下面三个报错可以忽略：
* ERROR:  duplicate key value violates unique constraint "monitor_host_threshold_pkey"
* ERROR:  duplicate key value violates unique constraint "monitor_job_pkey"
* ERROR:  duplicate key value violates unique constraint "monitor_user_pkey"

##### 验证数据
通过 `list 	node` 、`list host`、`list job`等命令来验证数据是否正确。

##### 验证新增的功能
背景介绍中报错的那个命令，初始化完成后，我们再来看下：
```sql
postgres=# list node pretty size all;
 nodename |        type        | port  |             nodepath              | nodesize 
----------+--------------------+-------+-----------------------------------+----------
 gc_1     | gtmcoord master    | 11018 | /data/danghb//data/adb40/d1/gc1  | 2957 MB
 gc_2     | gtmcoord slave     | 11019 | /data/danghb//data/adb40/d2/gc2  | 751 MB
 cd1      | coordinator master | 11010 | /data/danghb//data/adb40/d1/cd1   | 16 GB
 cd4      | coordinator master | 11013 | /data/danghb//data/adb40/d1/cd4   | 329 MB
 cd2      | coordinator master | 11011 | /data/danghb//data/adb40/d1/cd2   | 336 MB
 cd3      | coordinator master | 11012 | /data/danghb//data/adb40/d1/cd3   | 336 MB
 db1_1    | datanode master    | 11020 | /data/danghb//data/adb40/d1/db1   | 4895 MB
 db2_1    | datanode master    | 11030 | /data/danghb//data/adb40/d1/db2   | 9292 MB
 db3_1    | datanode master    | 11040 | /data/danghb//data/adb40/d1/db3   | 9434 MB
 db1_2    | datanode slave     | 11021 | /data/danghb//data/adb40/d2/db1   | 4307 MB
 db1_3    | datanode slave     | 11022 | /data/danghb//data/adb40/d2/db1_3 | 4307 MB
 db1_4    | datanode slave     | 11023 | /data/danghb//data/adb40/d2/db1_4 | 4307 MB
 db2_2    | datanode slave     | 11031 | /data/danghb//data/adb40/d2/db2   | 4686 MB
 db3_2    | datanode slave     | 11041 | /data/danghb//data/adb40/d2/db3   | 4645 MB
(14 rows)

postgres=# list node size all;
 nodename |        type        | port  |             nodepath              |  nodesize   
----------+--------------------+-------+-----------------------------------+-------------
 gc_1    | gtm master         | 11018 | /data/danghb//data/adb40/d1/gc1  |  3100170258
 gc_2    | gtm slave          | 11019 | /data/danghb//data/adb40/d2/gc2  |   787110334
 cd1      | coordinator master | 11010 | /data/danghb//data/adb40/d1/cd1   | 17022981962
 cd4      | coordinator master | 11013 | /data/danghb//data/adb40/d1/cd4   |   344869775
 cd2      | coordinator master | 11011 | /data/danghb//data/adb40/d1/cd2   |   351882452
 cd3      | coordinator master | 11012 | /data/danghb//data/adb40/d1/cd3   |   351850439
 db1_1    | datanode master    | 11020 | /data/danghb//data/adb40/d1/db1   |  5133107468
 db2_1    | datanode master    | 11030 | /data/danghb//data/adb40/d1/db2   |  9743861157
 db3_1    | datanode master    | 11040 | /data/danghb//data/adb40/d1/db3   |  9892059237
 db1_2    | datanode slave     | 11021 | /data/danghb//data/adb40/d2/db1   |  4516621960
 db1_3    | datanode slave     | 11022 | /data/danghb//data/adb40/d2/db1_3 |  4516623037
 db1_4    | datanode slave     | 11023 | /data/danghb//data/adb40/d2/db1_4 |  4516630156
 db2_2    | datanode slave     | 11031 | /data/danghb//data/adb40/d2/db2   |  4913885024
 db3_2    | datanode slave     | 11041 | /data/danghb//data/adb40/d2/db3   |  4870957246
(14 rows)

```
成功返回结果，验证通过。

##### 设置节点属性
因为没有初始化集群，所以需要将节点的initialized和incluster设置为true，adbmgr提供了命令来操作：
```sql
postgres=# set cluster init;
SET CLUSTER INIT
postgres=# 
```

##### 重新拉slave（可选）
如果环境中存在mgr slave，在mgr master初始化完成之后，需要把重新拉一份slave，具体操作如下：
```shell
# 备份mgr 数据目录
mv /data/adb/mgr /data/adb/mgr_bak
# 用pg_basebackup 拉取备份
pg_basebackup -h adb05 -p 16432 -U adb -D /data/adb/mgr --nodename mgr -Xs -Fp -R
# 修改数据目录权限
chmod 700 /data/adb/mgr
# 启动mgr slave
mgr_ctl start -D /data/adb/mgr
```

##### 注意事项
* 在初始化过程中，如果发生数据节点故障，可能导致无法自动切换，所以要选择合适的时间点操作。

