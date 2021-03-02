a2x-admin-manual

AntDB to 其他异构数据库增量同步工具a2x 使用说明

## a2x 工具介绍

### 概述

工具名称：postgres2oracle.jar
工具路径：/home/antdb/app/a2x

|项目|功能说明|
|:--|:-------|
|postgres2oracle.jar|主程序|
|c3p0-config.xml|数据源的配置信息|
|config.conf|工具运行配置信息|
|log4j2.xml|日志相关|
|recover.conf|同步状态配置信息，用于异常退出后工具重新启动时恢复所需参数|

### 原理图说明

![image](image/a2o_01.jpg)

a2x通过解析源端wal的交易信息，

将源端的标准sql解析为人们可以理解的json格式，

再封装为目标端数据库可执行的标准sql格式，

并在目标端应用该表交易。


### 解码过程

在AntDB执行的标准sql

![image](image/a2o_02.png)

经a2x解码后的格式

Insert

![image](image/a2o_03.png)

Update

![image](image/a2o_04.png)

Delete

![image](image/a2o_05.png)

### 注意事项

1. AntDB打开归档日志功能

2. 不支持DDL操作

3. 目标端数据库禁用触发器和外键约束

4. 源端已经安装wal2json解码插件

5. 若在同步期间，想新增DDL操作，则按下述步骤操作
```shell
step1.  antdb和目标数据库侧同时创建表；
step2.  若表没有主键，在antdb侧执行下述sql，否则该表同步异常。
alter table xxx replica identity full;
```

6. 勿执行大批量的insert/update操作
```shell
insert into xxx select * from xxx
select * into xxx from xxx;
```

## 解码插件adb_wal2json的编译安装
1. 解压
```shell
unzip adb_wal2json.zip
```

2. 编译
```shell
cd adb_wal2json
USE_PGXS=1 make
```

3. 安装
```shell
cd adb_wal2json
USE_PGXS=1 make install
```

4. 验证
```shell
postgres=# select proname from pg_proc where proname in ('pg_create_logical_replication_slot','pg_logical_slot_peek_changes','pg_logical_slot_get_changes');
              proname               
------------------------------------
 pg_create_logical_replication_slot
 pg_logical_slot_get_changes
 pg_logical_slot_peek_changes
(3 rows)
插件成功安装之后，会在数据库生成3个函数，其中：
pg_create_logical_replication_slot，创建逻辑slot的函数
pg_logical_slot_get_changes，发现WAL变化的函数
pg_logical_slot_peek_changes，消费WAL变化的函数
```

## AntDB源端数据库侧的调整
### 创建逻辑slot
a2x运行的前提是，必须预先在数据库创建一个逻辑slot
```shell
postgres=# SELECT pg_create_logical_replication_slot('test_slot', 'wal2json');
 pg_create_logical_replication_slot 
------------------------------------
 (test_slot,0/61362C60)
(1 row)
```

### 调整流复制的级别为logical
```shell
vim postgresql.conf
wal_level = 'logical'
max_wal_senders = '10'
重启数据库使配置生效
```

## 工具的部署和配置
### 部署
工具的版本包由二进制文件、配置文件和启停工具的shell脚本组成，上传服务器后，解压即可。

工具的版本包目录树结构如下：

├── conf
├── log
├── postgres2oracle.jar
├── start
└── stop

### 配置
1. 配置源端/目标端数据库连接信息
```
vim c3p0-config.xml
<?xml version="1.0" encoding="UTF-8"?>
<c3p0-config>
        <!-- oracle的配置信息 -->
        <named-config name="oracle-config">
                <property name="jdbcUrl">jdbc:oracle:thin:@//192.168.11.xxx:1521/dbtest</property>
                <property name="driverClass">oracle.jdbc.driver.OracleDriver</property>
                <property name="user">dbuster</property>
                <property name="password">dbpassword</property>
                <property name="acquireIncrement">0</property>
                <property name="initialPoolSize">10</property>
                <property name="minPoolSize">0</property>
                <property name="maxPoolSize">50</property>
        </named-config>
        <!-- postgresql配置信息 -->
        <named-config name="postgres-config">
                <property name="jdbcUrl">jdbc:postgresql://10.21.20.xxx:6432,10.21.20.xxx:6432,10.21.20.xxx:6432/dbtest?targetServerType=master</property>
                <property name="driverClass">org.postgresql.Driver</property>
                <property name="user">dbuser</property>
                <property name="password">dbpassword</property>
                <property name="acquireIncrement">0</property>
                <property name="initialPoolSize">10</property>
                <property name="minPoolSize">0</property>
                <property name="maxPoolSize">50</property>
        </named-config>
</c3p0-config>
主要调整jdbc的连接串/端口号/实例名/用户名称/用户密码，其他默认即可。
```

2. 配置工具运行时的相关信息
```
vim config.conf
#启动过程是否检查pg库中表的主键信息(默认检查)
check_primary_key=true
#需要同步的schema名称，按实际情况调整
schema=schematest
# 每次获取处理的事务个数，默认值： 1，建议调整为 100 - 1000 之间的值，以提高每次peek/get的事务数量
peek_change=200
# a2x对应的pg_logical_slot名称，按实际情况调整
slot_name=test_slot
#跳过未知的空事务(on,off)，建议on
skip_empty_transaction=on
#启用Oracle批量更新(on,off,auto)，建议on
oracle_batch=on
#Oracle批量更新每批的数据量(条)(0为不限制)建议调整为 100 - 1000 之间的值，以提高批量处理的效率
oracle_batch_size=1000
#每次peek或get事务时的附加参数。filter-tables 指peek/get时，过滤相关的信息，这些信息不会被同步至目标端；add-tables 正好相反，必须同步这些信息。
get_change_parameter='filter-tables','public.*,schematest.tablefilter1,*.tablefilter2'
get_change_parameter='add-tables','schematest.tableadd1,*.tableadd2'
#Oracle端执行Sql语句失败时是否停止，建议true
ora_exec_fail_stop=true
# 异常退出时执行的脚本。该参数目的是当同步工具异常退出前，可通过脚本通知维护人员，及时处理，一旦响应时间过久，容易引起大量数据积压。
exec_sh=send_mail.py
# 异常退出脚本所需的参数，若脚本无需参数，直接注释即可。
#exec_args=-a
```

3. recovery.conf文件说明

该文件是工具自动产生并维护的，无需人工干预。

该文件用于记录数据处理过程中的当前事务执行和已经执行的状态信息，并用于工具重启时恢复同步时的参照信息。

```shell
vim recovery.conf
curr_Status=SUCCESS
curr_Lsn=EE/E6BA3010
prev_Lsn=EE/E6B74680
curr_Time=2020-01-17 17\:03\:08.870507+08
prev_Status=SUCCESS
curr_Xid=40416418
prev_Time=2020-01-17 16\:20\:21.70906+08
prev_Xid=40416417
```

## 工具的使用和维护
在工具所在根目录 /home/antdb/app/a2x，有如下2个脚本

start

stop

其中 start 启动该工具  ；  stop 则手工停止该工具的运行

详细如下：

启动工具 

```shell
$ cd /home/antdb/app/a2x
$ vim start
调整脚本中的psqlconn的数据库连接信息
psqlconn="psql -d xxx -U xxx -p 6432 -h x.x.x.x -q -t"
$ ./start 
bak log
all table is ok that replica identity full
start postgres2oracle.jar
```

停止工具 
```shell
$ cd /home/antdb/app/a2x 
$ ./stop
stop postgres2oracle.jar
no postgres2oracle.jar is running

```

查看数据同步的延迟
```shell
postgres=# SELECT pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn() , confirmed_flush_lsn)) as sync_lag FROM pg_replication_slots  where slot_name = 'test_slot';
 sync_lag 
----------
 56 bytes
(1 row)
```

查看日志
```shell
cd /home/antdb/app/a2x
tail ./log/info/info.log -f
```

## 当AntDB HA发生切换后，a2x的操作步骤


1. 确认配置信息：检查c3p0-config.xml配置文件，若antdb的jdbcUrl尚未按下述配置，则请按下述配置调整jdbcUrl的连接串

```shell
jdbc:postgresql://10.21.20.117:6432,10.21.20.118:6432,10.21.20.119:6432/dmp?targetServerType=master
```

将AntDB集群中所有主从节点的  ip:port  连接串中，

通过targetServerType=master选项，控制jdbc驱动只往主从集群的 主节点(master server) 发送连接。

当HA切换后，JDBC驱动通过该参数，自动重新匹配新的master节点，并向新的master节点发起连接。



2. 启动a2x工具


```shell
$ cd /home/antdb/app/a2x
$ ./start 
bak log
all table is ok that replica identity full
start postgres2oracle.jar

```

3. 确认工具已经成功启动

通过查看日志，没有报错即启动成功

```shell
cd /home/antdb/app/a2x
tail postgres2oracle.jar.log -f
```

## a2x 的邮件告警功能

```shell
当AntDB数据库停止或发生HA切换时，a2x工具会自动停止

已经在a2x工具的config.conf配置文件中添加了下述配置项，通过send_mail.py脚本自动发送 'a2x 工具已停止' 的邮件告警。

exec_sh=send_mail.py

请接收到告警邮件后，迅速联网，并进行异常处理后，重新启动 a2x 工具。

脚本send_mail.py位于工具根目录的  conf/send_mail.py 下面，日志文件是同级目录下的 send_mail.py.log 。

```
