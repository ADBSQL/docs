# xc-xl-adb2.1-adb2.2功能对比
版本说明：
（选取xc及adb版本基于pg9.3内核版本，xl基于pg9.5内核）
```shell
pgxl版本：
commit b899b6c0126b54c698caa9ee99b428a25d360a6c
Author: Pavan Deolasee <pavan.deolasee@gmail.com>
Date:   Tue Oct 4 13:20:45 2016 +0530

pgxc版本：
commit efffd41798e1c80f15940f00b08a61fcf346333b
Author: Koichi Suzuki <koichi.dbms@gmail.com>
Date:   Sat Aug 27 08:09:34 2016 -0500

adb2.2版本：
commit 8014f7e876acc5d25624abfc1ef02de5a978f4cd
Author: ZhaoCheng <chengxiaozh@gmail.com>
Date:   Fri Oct 20 23:25:10 2017 +0800
```
测试资源配置：

类别|描述
--|--
操作系统|CentOS release 6.7（Linux version:2.6.32-642.6.1.el6.x86_64）
CPU|Intel(R) Xeon(R) CPU E5-2609 v3 @ 1.90GHz 12核
内存|64GB
DISK|1.6T SCSI
网卡|1000Gb

### 1、版本功能对比
---
#### 1.1、新增功能对比
---
功能 |Pgxc	|Pgxl	|ADBV2.1	|ADBV2.2	|链接和说明
--|--|--|--|--|--
自定义分片函数|	不支持|	不支持|	支持	|支持	|[自定义分片函数](#1)
Oracle语法兼容|	不支持|	不支持|	支持|	支持|	[ADB新增Oralce语法兼容](#oracle)
只读事务不获取事务号|	不支持|	支持|	不支持|	支持|	[只读事务不获取事务号](#read)
复制表union、in、exists、连接等进行优化，减少网络传输和计算|	无优化|	部分优化|优化|优化|	[复制表union、in、exists、连接等进行优化](#union)
优化pool manager|	经常出现get pool failed	|未优化	|优化|	优化|	ADB优化重构pool
Gtm 支持一主多从，同步异步模式|	不支持|	不支持|	不支持|	支持|	2.2版本重构了gtm，支持一主多从
Gtm纳入事务	|不支持|	不支持|	不支持|	支持|	2.2版本gtm参与事务处理，保证全局事务
RemoteXACT辅助进程	|不支持	|不支持|	不支持|	支持|	[RemoteXACT manager](#RemoteXACT)
Remote xlog|	不支持|	不支持|	不支持|	支持|	[Remote xlog](#Remote)
Manager	|无|无	|无	|有	| [ADB Manager](#manager)
Monitor	|无	|无	|有|	有|	[ADB monitor](#monitor)

#### 1.2、其他功能对比
功能|	Pgxc|	Pgxl|	ADBV2.1|	ADBV2.2|	链接和说明
--|--|--|--|--|--
Gtm 高可用|	支持|	存在缺陷	|支持|	支持|	[Gtm高可用](#hive)
Failover gtm对原mater进程清理预防错误|	不支持|	不支持|	支持|	支持|	[Failover gtm](#failover)
高并发操作sequence,出现gtm.control中sequence存在，而coordinator节点和datanode节点中丢失|	有|	有|	可修正|	无|	[sequence丢失](#seq)

#### 1.3、异常场景对比
问题描述|	Pgxc|	Pgxl|	ADBV2.1|	ADBV2.2|链接
--|--|--|--|--|--
coordinator和datanode中事务状态不一致|	有|	有|	无|	无|	[coordinator和datanode中事务状态不一致](#2)
gtm一主一从，先failover gtm , add slave后再次切换|	偶现coredump|	gtm高可用存在缺陷(参考高可用切换)	|正常|	正常|	[Gtm 高可用](#failover)
 |[1000并发](#1000)，datanode切换，coordinator会卡顿一段时间，之后恢复正常。|	无|	切换完成，可以正常读写但有core文件产生|	无|	无	|[benchmarksql1000并发下datanode切换](#core)
 |Datanode failover后写数据失败|	有|	无|	无|	无|	[Datanode failover后写数据失败](#faildb)
 |	coordinator与gtm_proxy不安装在一个节点服务器，pgxc_ctl failover gtm后，该coordinator连接gtm的ip port未修改为gtm_proxy|	有|	有|	无|	无|	[coordinator与gtm_proxy不安装在一个节点服务器](#6)
创建临时表后，向临时表中插入数据或者创建函数中使用这个表，都会报：这个临时表不存在或者类型未定义|	产生core文件|	有|	无	|无|	[ERROR:  type compos does not exist](#type)
 |	psql会话中设置事务隔离级别造成gtm_proxy发送消息混乱	|有	|无	|无|	无|	[会话中设置事务隔离级别造成消息混乱](#tru)
  |表属性丢失|	无	|验证经常发生死锁无法进行|	无|	无|	[属性丢失](#4)
 |	Gtm重要信息保护	|无|	无|	有|	有|	[Gtm信息保护](#safe)
 
 
 
### 操作流程
---
##### <div id="1">自定义分片函数</div>

Pgxl
```sql
test=# create function fun_519_11(v1 int,v2 int) returns int
test-# as $$
test$# begin
test$# return v1*v2;
test$# end;
test$# $$
test-# language plpgsql;
CREATE FUNCTION
test=# create table t_519_11(id int,name int,v3 int) distribute by replication;
CREATE TABLE
test=# insert into t_519_11 values (1,1,1),(1,2,2),(2,2,2);
INSERT 0 3
test=# select * from t_519_11 ;
 id | name | v3 
----+------+----
  1 |    1 |  1
  1 |    2 |  2
  2 |    2 |  2
(3 rows)

test=# alter table t_519_11 distribute by fun_519_11(id,v3);
ERROR:  syntax error at or near ","
LINE 1: alter table t_519_11 distribute by fun_519_11(id,v3);
                                                        ^
test=# 
```

ADB
```sql
test=# create function fun_519_11(v1 int,v2 int) returns int
test-# as $$
test$# begin
test$# return v1*v2;
test$# end;
test$# $$
test-# language plpgsql;
CREATE FUNCTION
test=#  create table t_519_11(id int,name int,v3 int) distribute by replication;
CREATE TABLE
test=# insert into t_519_11 values (1,1,1),(1,2,2),(2,2,2);
INSERT 0 3
test=#  select * from t_519_11 ;
 id | name | v3 
----+------+----
  1 |    1 |  1
  1 |    2 |  2
  2 |    2 |  2
(3 rows)

test=# alter table t_519_11 distribute by fun_519_11(id,v3);
ALTER TABLE
test=# \d+ t_519_11 
                       Table "public.t_519_11"
 Column |  Type   | Modifiers | Storage | Stats target | Description 
--------+---------+-----------+---------+--------------+-------------
 id     | integer |           | plain   |              | 
 name   | integer |           | plain   |              | 
 v3     | integer |           | plain   |              | 
Has OIDs: no
Distribute By: fun_519_11(id, v3)
Location Nodes: ALL DATANODES
```
##### <div id="oracle">oracle语法及函数兼容</div>
ADB(支持会话级,语句级显式调用，全局server级（通过修改配置文件postgresql.conf grammar=oracle）):
```sql
--会话级
postgres=# set grammar = oracle;
SET
postgres=# select sysdate from dual;
     ora_sys_now     
---------------------
 2017-11-03 16:31:26
(1 row)
                      
postgres=# /*pg*/select now();
              now              
-------------------------------
 2017-11-03 16:32:17.173877+08
(1 row)

postgres=# set grammar=postgres;
SET
--语句级
postgres=# /*ora*/ select sysdate from dual;
     ora_sys_now     
---------------------
 2017-11-03 16:35:12
(1 row)
```
##### <div id="read">只读事务不获取事务号</div>
pgxc和adb2.1版本，事务查询需要获取事务号。
```sql
postgres=# select txid_current_snapshot();
 txid_current_snapshot 
-----------------------
 2315:2315:
(1 row)

postgres=# select count(*) from a;
 count 
-------
     0
(1 row)

postgres=# select txid_current_snapshot();
 txid_current_snapshot 
-----------------------
 2317:2317:
(1 row)
```
Pgxl和2.2版本均支持只读事务不获取事务号功能，减少不必要处理和性能损耗:
```sql
postgres=# create table a (id int);
CREATE TABLE
postgres=# select txid_current_snapshot();
 txid_current_snapshot 
-----------------------
 3648155:3648155:
(1 row)

postgres=# select count(*) from a;
 count 
-------
     0
(1 row)

postgres=# select txid_current_snapshot();
 txid_current_snapshot 
-----------------------
 3648155:3648155:
(1 row)
```
##### <div id="RemoteXACT">RemoteXACT manager</div>
 
远端事务管理器，负责完成远端事务出现错误后的相关操作。
负责记录与重做或回滚远端的两阶段事务.不会出现各个节点存在未完成的两阶段事务而导致的事务挂起。


##### <div id="Remote">Remote xlog</div>
coordinator中记录了远端的执行日志(事务号、节点号操作等信息)，可以确定哪些节点完成了哪些操作(prepare 、commit prepared 、roolback prepared)，出现问题时可以进行相应处理。


##### <div id="manager">ADB Manager</div>
ADB Manager集群管理工具，manager通过与部署数据库机器上各个agent通信，管理数据库集群的初始化、启动、停止、高可用切换、新增节点及参数设置；manager可以部署在非数据库集群机器上，避免用户直接登陆数据库机器从而增强安全性，限制指定特定语法规则的操作命令增强对用户行为约束性。通过维护host、node、parm表来管理集群节点信息，方便大规模集群节点管理及部署。 

无需让所有节点都配置SSH，即可实现集群管理，更安全。
ADB Manager架构方便扩展，有利于集成辅助功能。通过manager及部署的agent获取数据库集群监控信息，相关监控信息存储在manager端，实现monitor集群监控功能。 

##### <div id="monitor">ADB monitor</div>
ADB monitor实现对数据库部署机器cpu、io、网络、内存及数据库集群节点数据量、tps、qps、缓存命中率、提交回滚率、连接数、锁等待数、长事务、空闲事务、prepare两阶段事务、慢日志、主机参数阈值告警、数据库参数阈值告警功能。 

##### <div id="2">coordinator和datanode中事务状态不一致</div>

操作步骤
1个coordinator 2个datanode

连接coordinator|Datanode1|Datanode1
--|--|--
Create table t5(a int primary key) distribute by replication;| |
begin;| |
insert into t5 values(1);| | 
EXECUTE DIRECT ON (dn1) 'select pg_backend_pid()'; | |
EXECUTE DIRECT ON (dn1) 'select pg_backend_pid()'; | |
 | |Gdb attach dn1 进程|Gdb attach dn2 进程
 | |b FinishPreparedTransaction|b FinishPreparedTransaction
commit;| | 
 | | Gdb finish 执行完该函数 | 不执行
 | | 外部kill掉此进程|外部kill掉此进程
postgres=# commit;| | 
WARNING: unexpected EOF on datanode connection| |
ERROR: Failed to COMMIT the transaction on one or more nodes| |	

PGXC
```shell 
node :coord1 ,status :aborted
node :db1    ,status :committed
node :db2    ,status :prepared
```
Pgxl

Coordinator:
```sql
postgres=#  select * from pgxc_prepared_xacts;
 pgxc_prepared_xact 
-----------------------------------------
_$XC$52024:coord1:F:2:0-2885965:-79866771
(1 row)
postgres=# select * from t5;
 a
---
(0 rows)
```

Datanode2:
```sql
postgres=# select * from pg_prepared_xacts ;
 transaction | gid                                     | prepared                     | owner   | database 
---------------+-----------------------------------------+----------------------------+---------+----------
       52024  _$XC$52024:coord1:F:2:0-2885965:-79866771   2016-10-20 16:45:59.18151+08   pgxl      postgres
(1 row)
postgres=# select * from t5;
 a
---
(0 rows)
```
Datanode1:
```sql
postgres=# select * from pg_prepared_xacts ;
 transaction | gid | prepared | owner | database 
-------------+-----+----------+-------+----------
(0 rows)
postgres=# select * from t5;
 a
---
 1
(1 row)
```


##### <div id="type">ERROR:  type compos does not exist</div>
Pgxc
```sql
postgres=# create temp table compos (f1 int,f2 text);
CREATE TABLE
postgres=# insert into compos values (1,'aaaa');
INSERT 0 1
postgres=# create function fcompos1(v compos) returns void as $$
postgres$# insert into compos values (v.*);
postgres$# $$ language sql;
The connection to the server was lost.Attempting reset:Failed.
!>
--产生core文件
```

Pgxl
```sql
postgres=# create temp table compos (f1 int,f2 text);
CREATE TABLE
postgres=# insert into compos values (1,'aaaa');
INSERT 0 1
postgres=# create function fcompos1(v compos) returns void as $$
postgres$# insert into compos values (v.*);
postgres$# $$ language sql;
ERROR:  type compos does not exist
```
ADB
```sql
postgres=# create temp table compos (f1 int,f2 text);
CREATE TABLE
postgres=# insert into compos values (1,'aaaa');
INSERT 0 1
postgres=# create function fcompos1(v compos) returns void as $$
postgres$# insert into compos values (v.*);
postgres$# $$ language sql;
CREATE FUNCTION
```

##### <div id="seq">sequence丢失</div>
pgxc  pgxl

创建sql脚本,vim seq.sql内容如下：
```sql
create sequence  seq_1 increment by 1 minvalue 1 no maxvalue start with 1;
select nextval('seq_1');
select currval('seq_1');
drop sequence seq_1;
create sequence  seq_1 increment by 1 minvalue 1 no maxvalue start with 1;
select nextval('seq_1');
drop sequence seq_1;
```
用pg自带的pgbench对上面的脚本进行100并发1分钟，结果：
```shell
pgxc@localhost1:~$pgbench  -c 100 -j 100 -n -T 180 -d postgres -U pgxc -p 8032 -f ./seq.sql 
query mode: simple
number of clients: 100
number of threads: 100
duration: 60 s
number of transactions actually processed: 355
tps = 5.903082 (including connections establishing)
tps = 5.904042 (excluding connections establishing)

```
连接coordinator:
```sql
pgxc@localhost1:~/pgxc_data/gtm$psql -d postgres -U pgxc -p 8032
psql (PGXC 1.2devel, based on PG 9.3.10)
Type "help" for help.

postgres=# \ds
No relations found.
```
此时，gtm的控制文件中存在该seq的信息：
```shell
pgxc@localhost1:~/pgxc_data/gtm$vim gtm.control 
22483
postgres.public.seq_1\00        2001    1       1       1       9223372036854775806     f       f       1
```
再开启一个coordinator连接会话，创建sequence出错：
```sql
pgxc@localhost1:~$psql -d postgres -U pgxc -p 8032        
psql (PGXC 1.2devel, based on PG 9.3.10)
Type "help" for help.
postgres=# create sequence  seq_1 increment by 1 minvalue 1 no maxvalue start with 1;
ERROR:  GTM error, could not create sequence

```
备注：还会偶现，gtm 中sequence信息不存在，而在coordinator节点和datanode节点中存在的现象，本次实验中就不再详细描述。
##### <div id="safe">Gtm信息保护</div>
pgxc pgxl:
```shell 
[pgxl@localhost1 gtm]$ ll
total 32
-rw------- 1 pgxl pgxl  2440 Aug 28 15:42 gtm.conf
-rw------- 1 pgxl pgxl   611 Oct 31 19:35 gtm.control
-rw-rw-r-- 1 pgxl pgxl 11988 Sep 14 14:20 gtm.log
-rw-rw-r-- 1 pgxl pgxl    28 Sep 14 14:20 gtm.opts
-rw------- 1 pgxl pgxl    28 Sep 14 14:20 gtm.pid
-rw------- 1 pgxl pgxl   334 Sep 14 14:20 register.node
```
 Gtm.control文件中记录了gtm很多关键的信息，没有进行保护和隐藏

ADBV2.1:
```shell
[autoci@localhost1 gtm]$ ll
total 1420
-rw------- 1 autoci autoci    2375 Oct  9 09:50 gtm.conf
-rw-rw-r-- 1 autoci autoci 1432046 Oct 31 19:09 gtm.log
-rw-rw-r-- 1 autoci autoci      35 Oct 31 04:00 gtm.opts
-rw------- 1 autoci autoci      35 Oct 31 04:00 gtm.pid
-rw------- 1 autoci autoci     483 Oct 31 04:01 register.node
[autoci@localhost1 gtm]$ ll -la
total 1432
drwx------ 2 autoci autoci    4096 Oct 31 04:00 .
drwxrwxr-x 7 autoci autoci    4096 Oct  9 09:51 ..
-rw------- 1 autoci autoci    2375 Oct  9 09:50 gtm.conf
-rw-rw-r-- 1 autoci autoci       7 Oct 31 19:00 .gtm.control
-rw-rw-r-- 1 autoci autoci 1432046 Oct 31 19:09 gtm.log
-rw-rw-r-- 1 autoci autoci      35 Oct 31 04:00 gtm.opts
-rw------- 1 autoci autoci      35 Oct 31 04:00 gtm.pid
-rw------- 1 autoci autoci     483 Oct 31 04:01 register.node
```
ADBV2.2:

v2.2版本为了解决xc xl的gtm 不参与2PC事务架构带来的业务场景问题，重构了全局事务管理器（AGTM）模块。


##### <div id="tru">会话中设置事务隔离级别造成消息混乱</div>
Pgxc
执行错误，产生core文件
```sql
postgres=# begin;
BEGIN
postgres=# set transaction isolation level serializable;           
SET
postgres=# create table cursor(a int,b int) distribute by hash(a);
The connection to the server was lost.Attempting reset:Failed.
!>
--产生core文件
```
Pgxl
运行正常
```sql
postgres=# begin;
BEGIN
postgres=# set transaction isolation level serializable;           
SET
postgres=# create table cursor(a int,b int) distribute by hash(a);
CREATE TABLE
postgres=# commit;
COMMIT
postgres=# \d cursor 
               Table "public.cursor"
 Column |  Type   | Collation | Nullable | Default 
--------+---------+-----------+----------+---------
 a      | integer |           |          | 
 b      | integer |           |          | 

```

##### <div id="failover">Failover gtm</div>
Pgxl  pgxc
Failover gtm后原有gtm  master进程仍然存在,此时进程能够正常接受请求，可能发生不可预知的错误。
```shell
[pgxl@localhost1 gtm]$ ps xft | grep gtm
 9517 pts/1    S+     0:00                  \_ grep gtm
23776 ?        Sl   201:19 gtm_proxy -D /home/pgxl/data/pxy1
23673 ?        Sl     4:30 gtm -D /home/pgxl/data/gtm
```


##### <div id="hive">Gtm 高可用</div>
Pgxl 
集群当前gtm配置信息
```shell
Finished reading configuration.
   ******** PGXC_CTL START ***************

Current directory: /home/pgxl/pgxc_ctl
PGXC show config gtm all
GTM Master: host: node1
    Nodename: 'gtm', port: 12201, dir: '/home/pgxl/data/gtm'    ExtraConfig: 'none', Specific Extra Config: 'none'
GTM Slave: host: node2
    Nodename: 'gtmSlave', port: 12202, dir: '/home/pgxl/data/gtm'    ExtraConfig: 'none', Specific Extra Config: 'none'
```
Gtm_proxy中文件的配置信息
```shell
# Added at initialization, 20170828_12:08:47
nodename = 'gtm_pxy1'
listen_addresses = '*'
port = 12231
gtm_host = 'node1'
gtm_port = 12201
gtm_connect_retry_interval = 1
# End of addition
#
worker_threads = 2
keepalives_idle=120
keepalives_interval=30
keepalives_count=2
```
进行gtm failover
```shell
conf
Finished reading configuration.
   ******** PGXC_CTL START ***************

Current directory: /home/pgxl/pgxc_ctl
PGXC failover gtm 
Failover gtm 
Running "gtm_ctl promote -Z -D /home/pgxl
```
Proxy配置文件信息没有变化，proxy并没有更新到新的gtm
```shell
nodename = 'gtm_pxy1'
listen_addresses = '*'
port = 12231
gtm_host = 'node1'
gtm_port = 12201
gtm_connect_retry_interval = 1
# End of addition
```

此时在连接psql是已经发生错误,如果使用原来的psql则卡死
```sql
[pgxl@localhost1 pxy1]$ psql -U zcxl -d postgres -p 12211
psql:FATAL:Could not obtain a transaction ID from GTM.The GTM might have failed or lost connectivity.
```
##### <div id="1000">1000 并发场景说明</div>
压测工具|benchmarksql
--|--
数据量|100个数据仓库，9张表，最小的表8.5KB，最大的表3.2GB。表最小100行，最大4千万行
集群架构|均采用2个coordinator，2个datanode master(datanode一主两从)
硬件配置|CPU：Intel(R) Xeon(R) CPU E5-2609 v3 @ 1.90GHz 12核<br>MEM:64GB<br>DISK:1.6T SCSI

##### <div id="core">benchmarksql 1000并发下datanode切换</div>
pgxl

```shell
(gdb) bt
#0   0x00000000006ca2b2 in producerDestroyReceiver (self-0x289d038) at producerReceiver.c:153
#1   0x000000000086b7ce in cleanipClosedProducers () at pquery.c:2496
#2   0x0000000000866589 in PostgresMain (argc=1, argv=0x253ee68, dbname=0x253ed60 "postgres", username=0x253ed38 "benchmarksql") at postgres.c:4576
#3   0x00000000007e1f97 in BackendRun (port=0x25a6000) at postmaster.c:4477
#4   0x00000000007e1702 in BackendStartup (port=0x25a6000) at postmaster.c:4151
#5   0x00000000007dda9f in ServerLoop () at postmaster.c:1801
#6   0x00000000007dd163 in PostmasterMain (argc=3, argv=0x2530140) at postmaster.c:1409
#7   0x000000000070fabe in main (argc=3, argv=0x2530140) at main.c:228
(gdb) p mystate
$1 = (producerstate *) 0x289d038
(gdb) p mystate->consumer
$2 = (DestReceiver *) 0x2871358
(gdb) p *mystate->consumer->rDestory
Cannot access memory at address 0x7f7f7f7f7f7f7f7f
(gdb) p isPGXCDataNode
$3 = 1 '\001'
```

##### <div id="union">复制表union、in、exist、连接等进行优化</div>
###### Union 语句

Pgxc  pgxl 
没有进行优化
```sql
test=# create table s (sid int,sname varchar(10)) distribute by replication;   
CREATE TABLE
test=# create table c (cid int,cname varchar(10)) distribute by replication;   
CREATE TABLE
test=# create table sc (sid int,cid int,grade int) distribute by replication;                    
CREATE TABLE
test=# insert into s values (1,'tom'),(2,'jack'),(3,'jane'),(5,'tony');
INSERT 0 4
test=# insert into c values (101,'math'),(102,'eng'),(103,'chay')
test-# ;
INSERT 0 3
test=# insert into sc values (1,101,80),(1,102,90),(2,102,80),(2,105,100),(3,101,90);
INSERT 0 5
test=# explain verbose select sid from s union select cid from c;  
                                          QUERY PLAN                                          
----------------------------------------------------------------------------------------------
 HashAggregate  (cost=302.36..325.56 rows=2320 width=4)
   Output: s.sid
   Group Key: s.sid
   ->  Append  (cost=100.00..296.56 rows=2320 width=4)
         ->  Remote Subquery Scan on all (datanode1)  (cost=100.00..136.68 rows=1160 width=4)
               Output: s.sid
               ->  Seq Scan on public.s  (cost=0.00..21.60 rows=1160 width=4)
                     Output: s.sid
         ->  Remote Subquery Scan on all (datanode1)  (cost=100.00..136.68 rows=1160 width=4)
               Output: c.cid
               ->  Seq Scan on public.c  (cost=0.00..21.60 rows=1160 width=4)
                     Output: c.cid
(12 rows)
```

ADB
```sql
test=# create table s (sid int,sname varchar(10)) distribute by replication;   
CREATE TABLE
test=# create table c (cid int,cname varchar(10)) distribute by replication; 
CREATE TABLE
test=# create table sc (sid int,cid int,grade int) distribute by replication;  
CREATE TABLE
test=# insert into s values (1,'tom'),(2,'jack'),(3,'jane'),(5,'tony');
INSERT 0 4
test=# insert into c values (101,'math'),(102,'eng'),(103,'chay');
INSERT 0 3
test=# insert into sc values (1,101,80),(1,102,90),(2,102,80),(2,105,100),(3,101,90);
INSERT 0 5
test=# explain verbose select sid from s union select cid from c;  
                                          QUERY PLAN                                           
-----------------------------------------------------------------------------------------------
 Data Note Scan on "__REMOTE_FQS_QUERY__" (cost=0.00..0.00 rows=0 width=0)
   Output: "*SELECT* 1".sid
   Node/s: db1
   Remote query: SELECT sid  FROM public.s UNION SELECT c.cid FROM public.c
(4 rows) 
```


###### 子查询in
Pgxl  进行优化
```sql
test=# explain verbose select * from sc where sid in (select sid from s);
                                     QUERY PLAN                                     
------------------------------------------------------------------------------------
 Remote Subquery Scan on all (datanode1)  (cost=29.00..76.10 rows=1020 width=12)
   Output: sc.sid, sc.cid, sc.grade
   ->  Hash Join  (cost=29.00..76.10 rows=1020 width=12)
         Output: sc.sid, sc.cid, sc.grade
         Inner Unique: true
         Hash Cond: (sc.sid = s.sid)
         ->  Seq Scan on public.sc  (cost=0.00..30.40 rows=2040 width=12)
               Output: sc.sid, sc.cid, sc.grade
         ->  Hash  (cost=26.50..26.50 rows=200 width=4)
               Output: s.sid
               ->  HashAggregate  (cost=24.50..26.50 rows=200 width=4)
                     Output: s.sid
                     Group Key: s.sid
                     ->  Seq Scan on public.s  (cost=0.00..21.60 rows=1160 width=4)
                           Output: s.sid
(15 rows)
```

Pgxc 没有进行优化
```sql
test=# explain verbose select * from sc where sid in (select sid from s);
                                          QUERY PLAN                                           
-----------------------------------------------------------------------------------------------
 Hash Semi Join  (cost=0.12..0.26 rows=10 width=12)
   Output: sc.sid, sc.cid, sc.grade
   Hash Cond: (sc.sid = s.sid)
   ->  Data Node Scan on sc "_REMOTE_TABLE_QUERY_"  (cost=0.00..0.00 rows=1000 width=12)
         Output: sc.sid, sc.cid, sc.grade
         Node/s: db1
         Remote query: SELECT sid, cid, grade FROM ONLY public.sc WHERE true
   ->  Hash  (cost=0.00..0.00 rows=1000 width=4)
         Output: s.sid
         ->  Data Node Scan on s "_REMOTE_TABLE_QUERY__1"  (cost=0.00..0.00 rows=1000 width=4)
               Output: s.sid
               Node/s: db1
               Remote query: SELECT sid FROM ONLY public.s WHERE true
(13 rows)
```

ADB进行了优化
```sql
test=# explain verbose select * from sc where sid in (select sid from s);
                          QUERY PLAN                      
-----------------------------------------------------------------------------------------------
 Data Note Scan on "__REMOTE_FQS_QUERY__" (cost=0.00..0.00 rows=0 width=0)
   Output: sc.sid, sc.cid, sc.grade
   Node/s: db1
   Remote query: SELECT sid, cid, grade  FROM public.sc WHERE (sid IN (SELECT s.sid FROM public.s)
(4 rows)
```

###### 子查询exists

Pgxl进行优化
```sql
test=# explain verbose select * from sc where exists (select sid from s where sc.sid=s.sid);
                                     QUERY PLAN                                     
------------------------------------------------------------------------------------
 Remote Subquery Scan on all (datanode1)  (cost=29.00..76.10 rows=1020 width=12)
   Output: sc.sid, sc.cid, sc.grade
   ->  Hash Join  (cost=29.00..76.10 rows=1020 width=12)
         Output: sc.sid, sc.cid, sc.grade
         Inner Unique: true
         Hash Cond: (sc.sid = s.sid)
         ->  Seq Scan on public.sc  (cost=0.00..30.40 rows=2040 width=12)
               Output: sc.sid, sc.cid, sc.grade
         ->  Hash  (cost=26.50..26.50 rows=200 width=4)
               Output: s.sid
               ->  HashAggregate  (cost=24.50..26.50 rows=200 width=4)
                     Output: s.sid
                     Group Key: s.sid
                     ->  Seq Scan on public.s  (cost=0.00..21.60 rows=1160 width=4)
                           Output: s.sid
(15 rows)
```

Pgxc没有优化
```sql
test=# explain verbose select * from sc where exists (select sid from s where sc.sid=s.sid);
                                          QUERY PLAN                                           
-----------------------------------------------------------------------------------------------
 Hash Semi Join  (cost=0.12..0.26 rows=10 width=12)
   Output: sc.sid, sc.cid, sc.grade
   Hash Cond: (sc.sid = s.sid)
   ->  Data Node Scan on sc "_REMOTE_TABLE_QUERY_"  (cost=0.00..0.00 rows=1000 width=12)
         Output: sc.sid, sc.cid, sc.grade
         Node/s: db1
         Remote query: SELECT sid, cid, grade FROM ONLY public.sc WHERE true
   ->  Hash  (cost=0.00..0.00 rows=1000 width=4)
         Output: s.sid
         ->  Data Node Scan on s "_REMOTE_TABLE_QUERY__1"  (cost=0.00..0.00 rows=1000 width=4)
               Output: s.sid
               Node/s: db1
               Remote query: SELECT sid FROM ONLY public.s WHERE true
(13 rows)
```

ADB进行优化
```sql
test=# explain verbose select * from sc where exists (select sid from s where sc.sid=s.sid);
                                          QUERY PLAN                                           
-----------------------------------------------------------------------------------------------
Data Note Scan on "__REMOTE_FQS_QUERY__" (cost=0.00..0.00 rows=0 width=0)
   Output: sc.sid, sc.cid, sc.grade
   Node/s: db1
   Remote query: SELECT sid, cid, grade  FROM public.sc WHERE (EXISTS  (SELECT s.sid FROM public.s WHERE (sc.sid=s.sid))
(4 rows) 
```

##### <div id="faildb">Datanode failover后写数据失败</div>
1.切换前insert无异常
```sql
postgres=# insert into t values(1),(2),(3),(4),(5),(6);
INSERT 0 6
postgres=# select * from t;
id 
----
1
2
5
6
3
4
(6 rows)
```
2、切换datanode

PGXC failover datanode db1

3、先不新增db1的slave节点，直接在coord1（与原master db1合设）新开一个psql窗口，执行insert
```sql
postgres=# begin;
BEGIN
postgres=# insert into t values(11),(12),(13),(14),(15),(16);
INSERT 0 6
postgres=# end;

--一直hang在那边，没有COMMIT的打印，发现这条语句其实是在往原master db1写数据
```

##### <div id="6">coordinator与gtm_proxy不安装在一个节点服务器</div>
pgxc pgxl
coordinator与gtm_proxy不安装在一个节点服务器，init 时，coordinator 连接GTM信息保存的是gtm的，而不是gtm_proxy。
failover gtm 后，现象一样。


##### <div id="4">属性丢失</div>
操作

step 1:
数据丢失测试内容：
- 1.创建一个多列属性的表
- 2.插入数据（比如百万行）
- 3.执行更新操作
- 4.执行删除操作
- 5.执行删除表操作

重复循环1，2，3，4，5 

step 2:

所有datanode、coordinator都进行vacuum ,vacuum full 表， vacuum freeze表。每个coordinator或者datanode对一个单独的脚本一直循环运行

Pgxl
执行一段时间后发生死锁
