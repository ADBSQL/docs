# **AntDB集群管理工具(Adbmgr)使用手册**

### **关键字列表**

关键字 | 解释
---|---
Adbmgr | 管理AntDB集群的一个管理工具，可以快速部署和方法管理AntDB 集群。 
AntDB 集群 | 即AntDB 分布式数据库，它是有多个单节点组成。 
节点/AntDB节点 | 即AntDB分布式数据库中的单个节点。节点分三种类型：Coordinator节点，Agtm节点和Datanode节点。 
agent | AntDB manager通过agent进程管理AntDB集群。 
hba | 允许哪些IP范围的客户端通过哪种认证方式访问指定的数据库。

--------------------------------------------------------
##  第一章 介绍Adbmgr

### 1.1 Adbmgr简介

   Adbmgr 是针对AntDB 集群的管理工具，具有管理AntDB集群的所有功能，包括AntDB集群的初始化，启动，停止；所有集群节点的参数设置；也包括AntDB集群的扩缩容等功能。
Adbmgr 与AntDB 集群之间的关系如下图所示：
![集群架构图](https://user-images.githubusercontent.com/13678346/38128804-abffa1de-342e-11e8-85a9-61aa211fd118.png)

AntDB集群部署可以在多台机器上，Adbmgr 为了实现管理AntDB 集群的功能，需要在每台主机上启动一个叫agent的进程，
Adbmgr 通过agent进程实现对AntDB集群的管理。Adbmgr 包括对agent进程的管理.

比如，用户执行了一个 start 命令来启动host1主机上的某个集群节点，Adbmgr 就会把start命令传给host1主机上的agent进程，由agent进程执行start命令；然后agent把start命令的执行结果传给Adbmgr 并显示为用户命令的执行结果。所以，AntDB集群所在的主机上都要启动一个agent进程。

为实现方便管理AntDB 集群的目的，在Adbmgr中有4张表，用于存储AntDB集群的基本配置，Adbmgr的所有操作命令都是针对这4张表进行操作的，所以有必要详细介绍这4张表。

### 1.2 host表介绍
---
Host表用于存放部署AntDB 集群的主机和agent进程等信息。如下图所示，是存放了2条主机信息的host表：

**示例**：
连接adbmgr执行：
```sql
postgres=# list host;
```
输出结果罗列在下面的表格中：

name| user| port| protocol| agentport|address|adbhome
---|---|---|---|---|---|---
 localhost1 | gd   |   22 | ssh      |     10906 | 10.21.20.175 | /data/antdb/app 
 localhost2 | gd   |   22 | ssh      |     10906 | 10.21.20.176 | /data/antdb/app 


Host表每列的详细解释如下：

列名|	描述
---|---
name|	主机名，即address列的IP address对应的主机名。
user| 用户名，部署AntDB集群的用户名。 
port|	Protocol列使用的协议的端口，ssh协议默认使用22端口。
protocol| Adbmgr 与agent通信使用的协议。默认使用ssh协议。 
agentport|	Agent进程使用的端口。这个需要由用户指定一个与其他进行不冲突的端口号。
address	|IP address，主机的ip 地址。
pghome	|部署AntDB 集群的可执行文件(二进制文件)在主机上的存放路径。

- 使用add host命令可以往host表中添加一行；
- 使用alter host命令可以修改行中的字段；
- 使用drop host可以删除host表中的一行；
- 使用list host命令可以显示host表中指定的host的信息。

上述命令的详细使用请参考第四章中host表相关命令。

下面是对host表常用操作命令例子：
```sql
add host localhost1( user=gd, protocol=ssh, address='10.21.20.175', agentport=10906, adbhome='/data/antdb/app');
alter host localhost1(adbhome='/opt/antdb/app');
drop host localhost1;
list host;
```
### 1.3 node表介绍

---
node 表用于保存部署AntDB 集群中每个节点的信息，同时包括从节点与主节点之间的同/异步关系等。

下面是使用list node命令查看的node表中的数据：
**示例**：
连接adbmgr执行：
```sql
postgres=# list node;
```
输出结果选取5条罗列在下面的表格中：

  name  |    host    |      type       | mastername | port  | sync_state |           path            | initialized | incluster | readonly
---|---|---|---|---|---|---|---|---|--
 coord1 | localhost1 | coordinator master |            |  6604 |            | /data/antdb/data/coord1 | t           | t|f
 coord2 | localhost2 | coordinator master |            |  6604 |            | /data/antdb/data/coord1 | t           | t|f
 db1    | localhost1 | datanode master |            | 16323 |            | /data/antdb/data/db1 | t           | t|f
 db2    | localhost2 | datanode master |            | 16323 |            | /data/antdb/data/db2 | t           | t|f
 gtm    | localhost1 | gtm master      |            |  7693 |            | /data/antdb/data/gtm | t           | t|f

 Node表中每列的解释如下：

 列名	| 描述
 ---|---
name	|AntDB 集群中节点的名字，比如coord2就是其中一个coordinator的名称。
host	|节点所在的主机，比如coord2节点部署在localhost2主机上。
type	|节点的类型，比如coord2就是AntDB集群中其中一个coordinator。
mastername|	主节点名字。本列只有从节点有效，对主节点无效
port	|端口号。节点部署在主机上使用的端口号。
sync_state	|同/异步关系。仅对从节点有效。值“sync”表示该从节点是同步从节点，“potential”表示该从节点是潜在同步节点，“async”表示该从节点是异步从节点。
path	|节点在主机上存放数据文件的路径。
initialized|	本节点是否已经初始化，“t”代表已经初始化，“f”代表没有初始化。
incluster|本节点是否在集群中，“t”代表本节点属于集群，“f”代表本节点不属于集群。
readonly|本节点是否是只读模式的，只针对coordinator类型的节点有效。“t”表示本节点为只读，“f”表示本节点为可读写。

下面是对node表常用操作命令例子（详细命令的使用方法参考第四章中node表相关命令）：
```sql
-- 向node表添加AntDB集群的节点信息：
add gtm master gtm_1 (host=localhost1,port=6768,path='/home/antdb/data/gtm');
add gtm slave gtm_2 for gtm_1 (host=localhost2,port=6768,path='/home/antdb/data/gtm');
add coordinator master coord1(host=localhost1, port=5532,path='/home/antdb/data/coord1');
add coordinator master coord2(host=localhost2, port=5532,path='/home/antdb/data/coord2');
add datanode master db1_1 (host=localhost1, port=15533,path='/home/antdb/data/db1');
add datanode slave db1_2 for db1_1 (host=localhost2, port=15533,path='/home/antdb/data/db1');
add datanode slave db1_3 for db1_1 (host=localhost3, port=15533,path='/home/antdb/data/db1');
add datanode master db2_1(host=localhost2, port=15436,path='/home/antdb/data/db2');
add datanode slave db2_2 for db2_1 (host=localhost1, port=15436,path='/home/antdb/data/db2');
add datanode slave db2_3 for db2_1 (host=localhost3, port=15436,path='/home/antdb/data/db2');
-- 修改node表中的某一列(在集群没有init以前可以随意修改node表中的值)：
alter datanode slave db1_2(port=34332);
alter datanode master db1_1(port=8899); 
-- 删除node表中的一行(在集群没有init以前可以随意添加和删除node表中的值)：
drop datanode slave db1_2;
drop datanode master db1_1;
drop coordinator master coord1;
drop gtm slave gtm_1;
-- 显示node表中所有节点信息：
list node;
```
 ### 1.4 param表介绍
---
 Param表用于存放AntDB集群中所有节点的postgresql.conf文件中变量的配置。所有在postgresql.conf文件中的变量都可以在这张表中设置并reload指定的节点。

下面是通过list param命令查看param表中的数据：
**示例**：
连接adbmgr执行：
```sql
postgres=# list param;
```
输出结果选取5条罗列在下面的表格中：

 nodename |          nodetype           |            key            | value 
 ---|---|---|---
  '*'        | coordinator master\|slave | listen_addresses          | '*'
  '*'        | coordinator master\|slave | max_connections           | 800
  '*'        | coordinator master\|slave | max_prepared_transactions | 800
  '*'      | datanode master\|slave |max_connections|1000
  ‘*’| gtm master\|slave |max_connections         | 2000             

Param表每列的解释如下：


列名	|描述
---|---
nodename	|AntDB 集群节点名字，星号“*”代表所有nodetype节点配置相同的配置。
nodetype	|节点类型。
key	|postgresql.conf文件中变量名
value|	key对应的变量值。

对param表常用操作命令举例如下(命令的具体使用方法参考第四章param表相关命令)：
```sql
-- 向param表中添加一行：
set gtm all (max_connections=1200);
set gtm master gtm_1(superuser_reserved_connections=13);
set gtm slave gtm_2(superuser_reserved_connections=14);
set coordinator all(autovacuum_max_workers=5);
set coordinator coord1(checkpoint_segments=128);
set coordinator coord2(checkpoint_segments=200);
set datanode all(default_statistics_target=100);
set datanode master db1_1 (autovacuum_vacuum_cost_delay='30ms');
set datanode slave db1_2 (autovacuum_vacuum_cost_delay='60ms');
set datanode slave db1_3 (autovacuum_vacuum_cost_delay='90ms');
-- 把参数重新设置为默认值：
reset datanode master all ( max_connections);
-- 显示param表中所有数据：
list param;
```
### 1.5 hba表介绍
---
hba表用于管理存放AntDB集群中所有coordiantor节点的pg_hba.conf文件中的配置项，当配置项被添加后，就会记录到此表中，用来标识。对于添加过的配置项，可以通过list hba命令显示。
hba表每列的解释如下：

列名	|描述
---|---
nodename| AntDB 集群节点名字，星号“*”代表所有nodetype节点配置相同的配置。 
hbavalue|	hba配置项的具体值。

对hba表常用操作命令举例如下(命令的具体使用方法参考第四章hba表相关命令)：
```sql
--向hba表中添加内容:
add hba all ("host all all 10.0.0.0 8 md5");
--显示hba表中的内容：
list hba;
--删除hba表中的内容：
drop hba all ("host all all 10.0.0.0 8 trust");
```
## 第二章 安装Adbmgr

### 2.1 源码安装Adbmgr

---
Adbmgr 与AntDB 集群的源码绑定在一起，所以编译Adbmgr，就是编译AntDB 集群的源码。

下面是编译安装步骤：  
step 1: mkdir build  
step 2: cd build  
step 3: ../AntDB/configure --prefix=/opt/adbsql --with-perl --with-python --with-openssl --with-pam --with-ldap --with-libxml --with-libxslt --enable-thread-safety --enable-debug --enable-cassert CFLAGS="-DWAL_DEBUG -O2 -ggdb3"  
step 4: make install-world-contrib-recurse  

备注：编译Adbmgr 过程中会提示各种库没有安装，如何安装这些库，请参考操作系统的库软件安装说明。

### 2.2 RPM安装 Adbmgr

---
通过交付人员提供的rpm包来安装（root用户执行）：

rpm -ivh adb-3.2.703602c-10.el7.centos.x86_64.rpm

注：在执行rpm安装之前，需要找AntDB交付人员咨询rpm包的安装路径。

### 2.3 初始化Adbmgr

---
编译Adbmgr 之后，会在指定的目录的bin目录下产生initmgr，和mgr_ctl可执行文件。要想初始化Adbmgr 还需要配置PATH变量才行。
向当前用户下的隐含文件bashrc中,执行vim ~/.basrhrc打开文件，追加如下内容：
```shell
export ADBHOME=/opt/app/antdb 
export PATH=$ADBHOME/bin:$PATH
export LD_LIBRARY_PATH=$ADBHOME/lib:$LD_LIBRARY_PATH
```
然后执行source .bashrc 使其生效即可。

注释：
对于ADBHOME参数内容需要根据AntDB的编译产生的二进制可执行文件的存放路径设置。
例如二进制文件存放在用户antdb的app目录下，则PGHOME=/home/antdb/app。
执行下面命令开始初始化Adbmgr：

- **initmgr –D /data/antdb/mgr1**

其中/data/antdb/mgr1是用户自己指定的存放Adbmgr 的安装目录，用户可随意设置。

初始化后，在指定的文件加下生成如下文件：
```shell
[gd@INTEL175 ~]$ cd /data/antdb/mgr1
[gd@INTEL175 mgr1]$ ll
total 112
drwx------ 5 gd gd  4096 Oct 17 17:28 base
drwx------ 2 gd gd  4096 Oct 17 17:28 global
drwx------ 2 gd gd  4096 Oct 17 17:28 pg_clog
drwx------ 2 gd gd  4096 Oct 17 17:28 pg_commit_ts
drwx------ 2 gd gd  4096 Oct 17 17:28 pg_dynshmem
-rw------- 1 gd gd  4450 Oct 17 17:28 pg_hba.conf
-rw------- 1 gd gd  1636 Oct 17 17:28 pg_ident.conf
drwx------ 4 gd gd  4096 Oct 17 17:28 pg_logical
drwx------ 4 gd gd  4096 Oct 17 17:28 pg_multixact
drwx------ 2 gd gd  4096 Oct 17 17:28 pg_notify
drwx------ 2 gd gd  4096 Oct 17 17:28 pg_replslot
drwx------ 2 gd gd  4096 Oct 17 17:28 pg_serial
drwx------ 2 gd gd  4096 Oct 17 17:28 pg_snapshots
drwx------ 2 gd gd  4096 Oct 17 17:28 pg_stat
drwx------ 2 gd gd  4096 Oct 17 17:28 pg_stat_tmp
drwx------ 2 gd gd  4096 Oct 17 17:28 pg_subtrans
drwx------ 2 gd gd  4096 Oct 17 17:28 pg_tblspc
drwx------ 2 gd gd  4096 Oct 17 17:28 pg_twophase
-rw------- 1 gd gd     4 Oct 17 17:28 PG_VERSION
drwx------ 3 gd gd  4096 Oct 17 17:28 pg_xlog
-rw------- 1 gd gd    88 Oct 17 17:28 postgresql.auto.conf
-rw------- 1 gd gd 22234 Oct 17 17:28 postgresql.conf
```
### 2.4 启动 Adbmgr

---
Adbmgr初始化成功后，就可以启动它了。有如下两种启动方式，可以任选一种执行。

- **mgr_ctl start -D /data/antdb/mgr1**
- **adbmgrd -D /data/antdb/mgr1 &**

注：/data/antdb/mgr1要与初始化路径保持一致。

方式一（推荐）：**mgr_ctl start -D /data/antdb/mgr1**
```shell
[gd@INTEL175 ~]$ mgr_ctl start -D /data/antdb/mgr1  
server starting
[gd@INTEL175 ~]$ LOG:  database system was shut down at 2017-10-17 17:38:15 CST
LOG:  MultiXact member wraparound protections are now enabled
LOG:  database system is ready to accept connections
LOG:  autovacuum launcher started
LOG:  adb monitor launcher started
```
方式二：**adbmgrd -D /data/antdb/mgr1 &**
```shell
[gd@INTEL175 ~]$ adbmgrd -D /data/antdb/mgr1 &  
[1] 85368
[gd@INTEL175 ~]$ LOG:  database system was shut down at 2017-10-17 17:39:42 CST
LOG:  MultiXact member wraparound protections are now enabled
LOG:  database system is ready to accept connections
LOG:  autovacuum launcher started
LOG:  adb monitor launcher started
```

若Adbmgr在启动的过程中报端口被占用，原因是当前端口号已经被其他进程使用（**Adbmgr默认使用端口是6432**）。需要修改/data/antdb/mgr1/postgresql.conf文件中变量port的值使其不与其他的进程冲突即可。

启动后，查看进程如下：
```shell
 67456 ?        S      0:00 /data/antdb/app/bin/adbmgrd -D mgr
 67458 ?        Ss     0:00  \_ adbmgr: checkpointer process   
 67459 ?        Ss     0:00  \_ adbmgr: writer process   
 67460 ?        Ss     0:00  \_ adbmgr: wal writer process   
 67461 ?        Ss     0:00  \_ adbmgr: autovacuum launcher process  
 67462 ?        Ss     0:00  \_ adbmgr: stats collector process  
 67463 ?        Ss     0:00  \_ adbmgr: adb monitor launcher process 
```
###  2.5 停止Adbmgr

---
命令格式：
- **mgr_ctl stop –D /data/antdb/mgr1**
```shell
[gd@INTEL175 ~]$ mgr_ctl stop -D /data/antdb/mgr1
waiting for server to shut down....LOG:  received fast shutdown request
LOG:  aborting any active transactions
LOG:  autovacuum launcher shutting down
LOG:  adb monitor launcher shutting down
LOG:  shutting down
LOG:  database system is shut down
 done
server stopped
[1]+  Done                    adbmgrd -D /data/antdb/mgr1
```

## 第三章 搭建AntDB 集群

如何使用Adbmgr 快速搭建AntDB 集群？首先需要通过psql客户端来了解一下Adbmgr是如何管理AntDB 集群的。
通过如下命令可以登录到Adbmgr上：

```
psql -d postgres -p 10090 
```

注：-p后面是端口号，因为配置文件中已将默认的6432修改为10090，这是为了防止端口冲突。

```shell
[gd@INTEL175 ~]$ psql -d postgres -p 10090                              
psql (ADB 3.0 based on PG 9.6.2 ADB 3.1devel 7fb79fd9d3)
Type "help" for help.

postgres=# 
```

### 3.1 添加主机(host)
---
Adbmgr通过三张表格管理集群，host、node和param表。

- host表用来存储搭建AntDB 集群所需要的所有主机信息。

- node表用来存储搭建AntDB 集群所有的节点信息。
- param表用来存储对AntDB 集群中节点参数设置的所有信息。

首先需要在host表中添加主机信息，后面gtm、datanode、coordinator会部署到这些主机上:

添加命令|	add host 主机名(address, agentport,user,adbhome);
--|--
**查看命令**|	list host;

部分参数可以不写，有默认值， 例如port默认22，user默认值是当前用户;

**举例：**
```sql
add host localhost1(port=22,protocol='ssh',adbhome='/home/antdb/app',address="10.1.226.201",agentport=8432,user='antdb');
add host localhost2(port=22,protocol='ssh',adbhome='/home/antdb/app',address="10.1.226.202",agentport=8432,user='antdb');
add host localhost3(port=22,protocol='ssh',adbhome='/home/antdb/app',address="10.1.226.203",agentport=8432,user='antdb');
```

### 3.2 deploy二进制程序

---
deploy命令会将AntDB的二进制执行文件打包发送到host表中所有主机上。对于第一次部署集群，或者集群的安装包有更新，为了集群安装的稳定性，则应首先手动清空集群下所有主机的执行文件。
在集群内各主机之间如果没有设置互信的情况下，执行deploy all需要输入用户密码（当前用户的登录密码），如果设置主机间互信，则可以省去密码的繁琐设置。
**命令：**

一次部署所有主机| deploy all password ' 123456'; 
---|---
**部署指定的主机**	|**deploy localhost1,localhost2 password ' 123456';**

### 3.3 启动agent

---
有两种方式：一次启动全部agent和单独启动一台主机agent（多个主机需要多次执行）。

注意：password是host表中主机user对应的linux系统密码，用于与主机通信，而非AntDB数据库的用户密码。
当密码是以数字开头时，需要加上单引号或者双引号，例如password ‘12345z’是正确的，password 12345z则会报错；如果密码不是以数字开头，则加不加引号都行。

一次启动全部agent| start agent all  password ' 123456'; 
---|---
**启动指定的agent**	|**start agent localhost1/localhost2 password ' 123456';**

当密码不对，启动agent失败时，报错如下：
```shell
postgres=# deploy localhost3 password '123456';    
  hostname  | status |                description                
------------+--------+-------------------------------------------
 localhost3 | f      | Authentication failed (username/password)
(1 row)
```

### 3.4 配置集群节点
---
Node表中添加gtm、coordinator、datanode master、datanode slave等节点信息。
注意：host名称必须来自host表，端口号不要冲突，path指定的文件夹下必须为空，否则初始化将失败并报错。这种设置，是防止用户操作时，忘记当前节点下还有有用的数据信息。

**添加命令：**

add节点 | command
---|---
添加coordinator信息|add coordinator master 名字(path = 'xxx', host='localhost1', port=xxx);
添加datanode master信息|add datanode master 名字(path = 'xxx', host='localhost1', port=xxx);
添加datanode slave信息，从节点与master不同名，所以指定的master必须存在，同异步关系通过SYNC_STATE参数设置|add datanode slave名字 for master_name (host='localhost2', port=xxx, path='xxx', SYNC_STATE='sync');
添加gtm信息，从节点必须与主节点不同名，所以指定的master必须存在，同异步关系通过SYNC_STATE参数设置|add gtm master名字(host='localhost3',port=xxx, path='xxx');add gtm slave名字 for maste_name(host='localhost2',port=xxx, path='xxx')

添加完成后，使用命令list node查看刚刚添加的节点信息

**举例：（gtm/datanode 均为2备机）**
```sql
add host localhost1(port=22,protocol='ssh',pghome='/home/antdb/app',address="10.1.226.201",agentport=8432,user='antdb');
add host localhost2(port=22,protocol='ssh',pghome='/home/antdb/app',address="10.1.226.202",agentport=8432,user='antdb');
add host localhost3(port=22,protocol='ssh',pghome='/home/antdb/app',address="10.1.226.203",agentport=8432,user='antdb');
add coordinator master coord0(path = '/home/antdb/data/coord/0', host='localhost1', port=4332);
add coordinator master coord1(path = '/home/antdb/data/coord/1', host='localhost2', port=4332);
add datanode master datanode0(path = '/home/antdb/data/datanode/0', host='localhost1', port=14332);
add datanode slave datanode0s for datanode0 (host='localhost2',port=14332,path='/home/antdb/data/datanode/00');
add datanode master datanode1(path = '/home/antdb/data/datanode/1', host='localhost2', port=24332);
add datanode slave datanode1s for datanode1(host='localhost1',port=24332,path='/home/antdb/data/datanode/11');
add gtm master gtm(host='localhost3',port=6655, path='/home/antdb/data/gtm');
add gtm slave gtms for gtm(host='localhost2',port=6655,path='/home/antdb/data/gtm_slave');
```

### 3.5 配置节点参数
---
**set param:**

同时设置所有同类型节点：
>set datanode|coordinator|gtm all(key1=value1, key2=value2...); 

设置某一个节点的参数:

>set{datanode|coordinator|gtm} {master|slave|extra} {nodename|all} (key1=value1, key2=value2...);

注意：相同的参数，slave的参数必须大于等于master，否则启动失败，查看log如下：
> 2017-10-17 10:50:55.730 CST 22023 0FATAL:  hot standby is not possible because max_prepared_transactions = 100 is a lower setting than on the master server (its value was 150)

**reset param:**

reset参数：
>reset {datanode|coordinator|gtm} {master|slave|extra} {nodename|all} (key1,key2...); （key,...） ；也可以支持 （key=value,key2,...），不过此时value值没有作用。
若parm表中存在参数设置，则删除

### 3.6 init all启动集群
---
集群的节点都已经配置完成，此时就可以使用命令init all启动集群了。如下图，可以看到init all内部的操作步骤。
```shell
postgres=# init all ;
    operation type     | nodename | status | description 
-----------------------+----------+--------+-------------
 init gtm master       | gtm      | t      | success
 start gtm master      | gtm      | t      | success
 init coordinator      | coord1   | t      | success
 init coordinator      | coord2   | t      | success
 start coordinator     | coord1   | t      | success
 start coordinator     | coord2   | t      | success
 init datanode master  | db2      | t      | success
 init datanode master  | db1      | t      | success
 start datanode master | db2      | t      | success
 start datanode master | db1      | t      | success
 init datanode slave   | db2      | t      | success
 init datanode slave   | db1      | t      | success
 start datanode slave  | db2      | t      | success
 start datanode slave  | db1      | t      | success
 config coordinator    | coord1   | t      | success
 config coordinator    | coord2   | t      | success
(12 rows)
```
通过monitor all 查看集群各个节点的运行状态：
```shell
postgres=# monitor all ;
 nodename |    nodetype           | status | description |     host     | port  
----------+-----------------+--------+-------------+--------------+-------
 coord1   | coordinator  master   | t      | running     | 10.1.226.201 |  4332
 coord2   | coordinator  master   | t      | running     | 10.1.226.202 |  4332
 db1      | datanode master       | t      | running     | 10.1.226.201 | 14332
 db1      | datanode slave        | t      | running     | 10.1.226.202 | 14332
 db2      | datanode master       | t      | running     | 10.1.226.202 | 24332
 db2      | datanode slave        | t      | running     | 10.1.226.201 | 24332
 gtm      | gtm master            | t      | running     | 10.1.226.203 |  6655
 gtm      | gtm slave             | t      | running     | 10.1.226.202 |  6655
(6 rows)
```
**至此，AntDB集群初始化完成！**

## 第四章 管理AntDB 集群

为了方便管理AntDB 集群，Adbmgr提供了一系列的操作命令。根据命令的功能可以划分为下面六类：
- agent相关命令
- host表相关命令
- node表相关命令
- param表相关命令
- hba表相关命令
- 集群管理相关命令

下面分别介绍这些命令的功能和格式。

### 4.1 help命令
在管理AntDB 集群的过程中，如果对某个命令的格式或者功能有任何的不明白，可以通过help命令查看该命令的功能描述和命令格式。

在psql客户端只要执行“\h”命令即可查看当前Adbmgr支持的所有命令列表，如下图所示：
```sql
postgres=# \h
Available help:
  ADBMGR PROMOTE              ALTER ITEM                  CLEAN GTM                   DROP USER                   LIST PARAM                  RESET COORDINATOR           START ALL
  ADD COORDINATOR             ALTER JOB                   CLEAN MONITOR               FAILOVER DATANODE           MONITOR AGENT               RESET DATANODE              START COORDINATOR
  ADD DATANODE                ALTER USER                  CONFIG DATANODE             FAILOVER GTM                MONITOR ALL                 RESET GTM                   START DATANODE
  ADD GTM                     APPEND ACTIVATE COORDINATOR CREATE USER                 FLUSH HOST                  MONITOR COORDINATOR         REVOKE                      START GTM
  ADD HBA                     APPEND COORDINATOR          DEPLOY                      GRANT                       MONITOR DATANODE            REWIND DATANODE             STOP AGENT
  ADD HOST                    APPEND COORDINATOR FOR      DROP COORDINATOR            INIT ALL                    MONITOR GTM                 REWIND GTM                  STOP ALL
  ADD ITEM                    APPEND DATANODE             DROP DATANODE               LIST ACL                    MONITOR HA                  SET CLUSTER INIT            STOP COORDINATOR
  ADD JOB                     APPEND GTM                  DROP GTM                    LIST HBA                    PROMOTE DATANODE            SET COORDINATOR             STOP DATANODE
  ALTER COORDINATOR           CHECKOUT DN SLAVE STATUS    DROP HBA                    LIST HOST                   PROMOTE GTM                 SET DATANODE                STOP GTM
  ALTER DATANODE              CLEAN ALL                   DROP HOST                   LIST ITEM                   REMOVE COORDINATOR          SET GTM                     SWITCHOVER DATANODE
  ALTER GTM                   CLEAN COORDINATOR           DROP ITEM                   LIST JOB                    REMOVE DATANODE             SHOW                        SWITCHOVER GTM
  ALTER HOST                  CLEAN DATANODE              DROP JOB                    LIST NODE                   REMOVE GTM                  START AGENT                 
postgres=#  
```
也可通过在“\h”后面添加具体的命令名称，查看指定命令的功能和格式。如下面所示：
```sql
postgres=# \h start
Command:     START AGENT
Description: start the agent process on the ADB cluster
Syntax:
START AGENT { ALL | host_name [, ...] } [ PASSWORD passwd ]

Command:     START ALL
Description: start all the nodes on the ADB cluster
Syntax:
START ALL

Command:     START COORDINATOR
Description: start the coordinator node type on the ADB cluster
Syntax:
START COORDINATOR [ MASTER | SLAVE ] ALL
START COORDINATOR { MASTER | SLAVE } node_name [, ...]

Command:     START DATANODE
Description: start the datanode node type on the ADB cluster
Syntax:
START DATANODE ALL
START DATANODE { MASTER | SLAVE } { ALL | node_name [, ...] }

Command:     START GTM
Description: start the gtm node type on the ADB cluster
Syntax:
START GTM ALL
START GTM { MASTER | SLAVE } node_name
```
下面章节的所有命令都可以通过上面的方式查看帮助信息。

### 4.2 agent相关命令
---
由第一章对Adbmgr  的介绍可知，agent进程是Adbmgr 实现管理AntDB 集群的关键。它是Adbmgr和AntDB 集群之间传输命令和返回命令执行结果的中间代理。所以要实现对AntDB 集群的管理，需要agent进程正常运行。管理agent进程的命令有Start agent，
Stop agent和Monitor agent三个命令，下面对这三个命令进行介绍。

#### 4.2.1 start agent
---
命令功能：
启动指定主机上的agent进程。指定的主机需在host表中，具体功能可通过帮助命令:
\h start agent 查看。

**命令格式：**
>START AGENT { ALL | host_name [, ...] } [ PASSWORD passwd ]

**命令举例：**
```sql
-- 启动host表中主机上所有主机上的agent进程（主机之间没有配置互信，所有主机上用户密码都为'sdg3565'）：
START AGENT ALL PASSWORD 'sdg3565';
-- 启动host表中主机上所有主机上的agent进程，（主机之间已经配置互信）：
START AGENT ALL ;
-- 启动host表中host1，host2主机上的agent进程（主机之间没有配置互信，host1，host2上用户密码都为'sdg3565'）：
START AGENT host1, host2 PASSWORD 'sdg3565';
-- 启动host表中host1，host2主机上的agent进程（主机之间已经配置互信）：
START AGENT host1, host2 ;
```
#### 4.2.2 stop agent
---
命令功能：
停止指定主机上的agent进程。指定的主机需在host表中，具体功能可通过帮助命令:\h stop agent 查看。

**命令格式：**
>STOP AGENT { ALL | host_name [, ...] }

**命令举例：**
```sql
-- 停止host表中所有主机上的agent进程：
STOP AGENT ALL ;
-- 停止host表中host1，host2主机上的agent进程：
STOP AGENT host1, host2 ;
```
#### 4.2.3 monitor agent
---
命令功能：
查看host表中指定主机上agent进程的运行状态。Agent进程有running 和not running两种运行状态。具体功能可通过帮助命令 \h stop agent  查看。

**命令格式：**
>MONITOR AGENT [ ALL | host_name [, ...] ]

**命令举例：**
```sql
-- 查看host表中所有主机上的agent进程的运行状态：
MONITOR AGENT ALL ;
-- 查看host表中host1，host2主机上agent进程的运行状态：
MONITOR AGENT host1, host2 ;
```
### 4.3 host表相关命令
---
Host表存放主机的相关信息，而主机信息又与node节点相关，所以在添加节点之前必须添加agent到host表中，在init all集群之前，必须先start agent，而这张host表就是用来管理host和agent。管理host表的命令有add host，alter host，drop host和list host三个命令，下面对这三个命令进行介绍。
#### 4.3.1 add host
---
命令功能：
添加新的主机到host表，参数可以选择添加，但是至少有一个，缺省参数会以默认值加入。
具体功能可通过帮助命令 \h add host 查看。

**命令格式：**
```sql
ADD HOST [IF NOT EXISTS] host_name ( option )

where option must be the following:

    ADDRESS = host_address,
    AGENTPORT = agent_port_number,
    ADBHOME = adb_home_path,
    PORT = port_number,
    PROTOCOL = protocol_type,
    USER = user_name
参数说明：
host_address：主机名对应的IP地址，不支持主机名。
agentport_number:agent进程监听端口号。
adb_home_path：数据库集群安装包存放路径。
host_name：主机名。
user_name：数据库集群安装用户。
protocol_type：数据库集群安装包传输使用的协议，可以为telnet，ssh。现只支持ssh。
port_number：protocol_type对用的协议的端口号，现只支持ssh，默认对应端口号22。
```
**命令举例：**
```sql
-- 添加主机名为host_name1信息：数据库安装用户antdb,数据库安装包使用ssh协议传输，host_name1对应的ip为”10.1.226.202”, agent监听端口5660，安装包存放路径设置为”/opt/antdb/app”：
ADD HOST host_name1(USER=antdb, PROTOCOL=ssh, ADDRESS='10.1.226.202', AGENTPORT=5660, adbhome='/opt/antdb/app');
```

#### 4.3.2 alter host
命令功能：
修改host表中的参数，可以是一个，也可以是多个。
具体功能可通过帮助命令 \h alter host 查看。

**注意：**
在集群初始化后，alter host命令无法进行操作。

**命令格式：**
```sql
ADD HOST [IF NOT EXISTS] host_name ( option )

where option must be the following:

    ADDRESS = host_address,
    AGENTPORT = agent_port_number,
    ADBHOME = adb_home_path,
    PORT = port_number,
    PROTOCOL = protocol_type,
    USER = user_name
参数说明：
host_name：主机名。
user_name：数据库集群安装用户。
protocol_type：数据库集群安装包传输使用的协议，可以为telnet，ssh。现只支持ssh。
port_number：protocol_type对用的协议的端口号，现只支持ssh，默认对应端口号22。
agentport_number:agent进程监听端口号。
host_address：主机名对应的IP地址，不支持主机名。
adb_home_path：数据库集群安装包存放路径。
```
**命令举例：**
```sql
--修改host_name1对用的agent端口为5610：
ALTER host_name1 (AGENTPORT=5610);
--修改host_name1对用的agent端口为5610, 安装包存放路径为 /home/data/antdbhome ：
ALTER host_name1 (AGENTPORT=5610, ADBHOME=’/home/data/antdbhome’);
```
#### 4.3.3 drop host
命令功能：
从host表中删除指定的主机，但是主机应当没有被依赖使用，不然会报错。
具体功能可通过帮助命令 \h drop host  查看。

**命令格式：**
> DROPHOST [ IF EXISTS ] host_name [, … ]

**命令举例：**
```sql
--连续删除host表中的主机名为localhost1和localhost2的成员：
DROP  HOST  localhost1, localhost2;
--删除host表中的主机名为localhost的成员：
DROP  HOST  localhost1;
```
#### 4.3.4 list host
命令功能：
显示host表中的成员变量，可以显示指定的主机部分参数，也可以全部显示，也可以显示host表的所有主机参数内容。

**命令格式：**
```sql
LIST HOST  [ ( option [, ...]) ] [ host_name [, ...] ]
where option can be one of:
    NAME
    USER
    PORT
    PROTOCOL
    AGENTPORT
    ADDRESS
    ADBHOME
参数说明：
NAME：主机名。
USER：数据库集群安装用户。
PORT：protocol_type对用的协议的端口号，现只支持ssh，默认对应端口号22。
PROTOCOL：数据库集群安装包传输使用的协议，可以为telnet，ssh。现只支持ssh。
AGENTPORT:agent进程监听端口号。
ADDRESS：主机名对应的IP地址。
ADBHOME：数据库集群安装包存放路径。
```
**命令举例：**
```sql
--显示host表中所有主机成员的信息：
LIST  host;
--显示host表中指定主机的成员信息：
LIST  host  localhost1;
--显示host表中指定主机的指定参数信息：
LIST  host  (user, agentport, address)  localhost1;
```
#### 4.3.5 flush host
命令功能：
集群初始化后，在机器IP地址出现变更时，首先通过alter host修改host表中所有需要修改的主机名对应的IP地址，再通过flush host去更新所有数据库节点中对应的IP地址信息。

**命令格式：**
>FLUSH HOST

**命令举例：**
```sql
--集群初始化后，机器IP发生变更，已完成host表中内容修改，需要刷新各个数据库节点IP地址信息：
FLUSH HOST;
```
### 4.4 node表相关命令
Node表用于保存部署AntDB 集群中每个节点的信息，同时包括从节点与主节点之间的同/异步关系等。管理node表的操作命令有:

- add node（包含ADD GTM、ADD COORDINATOR、ADD DATANODE）
- alter node（包含ALTER GTM、ALTER COORDINATOR、ALTER DATANODE）
- drop node（包含DROP GTM、DROP COORDINATOR、DROP DATANODE）
- list node

下面对这四个命令进行介绍

#### 4.4.1 add node
---
命令功能：
在node表中添加节点信息。具体功能可通过帮助命令“\h add gtm” 、”\h add coordinator”、”\h add datanode”查看。

**注意：**
Gtm和datanode均可存在多个备机，nodetype为slave。第一个添加的slave节点，默认为同步slave，后续添加的默认为潜在同步，sync_state字段值为`potential`

指定的节点数据存放路径需要为空目录，否则执行初始化时报错。

**命令格式：**
```sql
ADD COORDINATOR MASTER master_name ( option )
ADD DATANODE MASTER master_name ( option )
ADD DATANODE SLAVE slave_name FOR master_name ( option )
ADD GTM MASTER master_name ( option )
ADD GTM SLAVE slave_name FOR master_name ( option )
where option must be the following:

    HOST = host_name,
    PORT = port_number,
    SYNC_STATE = sync_mode,
	PATH = pg_data
	READONLY = readonly_type (仅仅在add coordinator时有效)
参数说明：
node_name：节点名称，对应node表name列。
host_name：主机名，与host表中主机名对应。
port_number：节点监听端口号。
Sync_mode：备机与主机的同异步关系，”on”、”t”、”true”均表示同步设置，”off”、”f”、”false”均表示异步设置。
pg_data：节点数据路径，需要保证该目录是空目录。
readonly_type：该coordinator是否为只读节点
```

**命令举例：**
```sql
-- 添加gtm master节点，主机为localhost1, 端口为6768，数据路径”/home/antdb/data/gtm”：
ADD GTM MASTER gtm (HOST=localhost1, PORT=6768, PATH='/home/antdb/data/gtm');
-- 添加gtm slave节点，主机为localhost2, 端口为6768，数据路径”/home/antdb/data/gtm”：
ADD GTM SLAVE gtms for gtm (HOST=localhost2, PORT=6768, SYNC=t, PATH='/home/antdb/data/gtm');
-- 添加coordinator节点coord1信息，主机为localhost1，端口为5532，数据路径”/home/antdb/data/coord1”：
ADD COORDINATOR master coord1(HOST=localhost1, PORT=5532,PATH='/home/antdb/data/coord1');
-- 添加datanode master节点db1，主机为localhost1，端口为15533，数据路径为”/home/antdb/data/db1”：
ADD DATANODE MASTER db1(HOST=localhost1, PORT=15533,PATH='/home/antdb/data/db1');
-- 添加datanode slave节点db1，主机为localhost2，端口为15533，数据路径为”/home/antdb/data/db1”：
ADD DATANODE SLAVE db1s for db1(HOST=localhost1, PORT=15533, SYNC=t, PATH= '/home/antdb/data/db1');
```

#### 4.4.2 alter node
---

命令功能：
在node表中修改节点信息。具体功能可通过帮助命令“\h alter gtm” 、”\h alter  coordinator”、”\h alter datanode”查看。

**注意：**
**在集群初始化前，可以通过alter node更新节点信息；在集群初始化后，只允许更新备机slave同异步关系sync_state列。**

**命令格式：**
```sql
ALTER GTM { MASTER | SLAVE } node_name ( option )
ALTER COORDINATOR MASTER node_name ( option )
ALTER DATANODE { MASTER | SLAVE } node_name ( option )  

where option can be one of:

    HOST =host_name,
    PORT = port_number,
    SYNC_STATE = sync_mode,
	PATH = pg_data

参数说明：
node_name：节点名称，对应node表name列。
host_name：主机名，与host表中主机名对应。
port_number：节点监听端口号。
Sync_mode：从节点与主节点的同异步关系。仅对从节点有效。值“sync”表示该从节点是同步从节点，“potential”表示该从节点是潜在同步节点，“async”表示该从节点是异步从节点。
pg_data：节点数据路径，需要保证该目录是空目录。
```

**命令举例：**
```sql
-- 集群初始化前，更新gtm master端口号为6666：
ALTER GTM MASTER gtm (PORT=6666);
-- 更新gtm slave与gtm master为同步关系：
ALTER GTM SLAVE gtms (SYNC_STATE='sync');
-- 更新gtm extra与gtm master为异步关系：
ALTER GTM SLAVE gtms (SYNC_STATE='async');
-- 集群初始化前，更新coordinator coord1端口为5532，数据路径为”/home/antdb/data/coord1”:
ALTER COORDINATOR master coord1 (PORT=5532, PATH=’/home/antdb/data/coord1’);
-- 集群初始化前，更新datanode master db1主机为localhost5，数据路径为”/home/antdb/data/db1”:
ALTER DATANODE MASTER db1 (HOST=localhost5, PATH=’/home/antdb/data/coord1’);
-- 更新datanode slave db1与主机datanode master为同步关系：
ALTER DATANODE SLAVE db1s (SYNC_STATE='sync');
-- 更新datanode extra db1与主机datanode master为异步关系：
ALTER DATANODE SLAVE db1s (SYNC_STATE='async');
```

#### 4.4.3 drop node
---
命令功能：
在node表中删除节点信息。具体功能可通过帮助命令“\h drop gtm” 、”\h drop coordinator”、”\h drop datanode”查看。

**注意：**
在集群初始化前，可以通过drop node删除节点信息，但是在存在备机的情况下，不允许删除对应的主机节点信息；在集群初始化后，不允许drop node操作。

**命令格式：**
```sql
DROP GTM { MASTER | SLAVE } node_name
DROP COORDINATOR MASTER node_name [, ...]
DROP DATANODE { MASTER | SLAVE } node_name [, ...]
```

**命令举例：**
```sql
-- 在集群初始化之前删除datanode slave db1s：
DROP DATANODE SLAVE db1s;
-- 在集群初始化之前删除coordinator coord1：
DROP COORDINATOR master coord1;
-- 在集群初始化之前删除gtm slave gtm：
DROP GTM SLAVE gtms;
-- 在集群初始化之前删除gtm master gtm：
DROP GTM MASTER gtm;
```

#### 4.4.4 list node
---
命令功能：
显示node表中节点信息。具体功能可通过帮助命令“\h list node” 查看。

**命令格式：**
```sql
LIST NODE COORDINATOR [ MASTER | SLAVE ]
LIST NODE DATANODE [ MASTER | SLAVE ]
LIST NODE DATANODE MASTER node_name
LIST NODE HOST host_name [, ...]
LIST NODE  [ ( option ) ] [ node_name [, ...] ]

where option can be one of:

    NAME
    HOST
    TYPE
    MASTERNAME
    PORT
    SYNC_STATE
    PATH
    INITIALIZED
    INCLUSTER

参数说明：
NAME：节点名称，对应node表name列。
HOST：主机名，与host表中主机名对应。
TYPE：节点类型，包含：GTM MASTER， GTM SLAVE，COORDINATOR MASTER，DATANODE 	MASTER，DATANODE SLAVE
MASTERNAME：备机对应的主机名，非备机对应为空。
PORT：节点监听端口号。
sync_state：从节点与主节点的同异步关系。仅对从节点有效。值“sync”表示该从节点是同步从节点，“potential”表示该从节点是潜在同步节点，“async”表示该从节点是异步从节点。
PATH：节点数据路径，需要保证该目录是空目录。
INITIALIZED：标识节点是否初始化。
INCLUSTER：标识节点是否在集群中。
```

**命令举例：**
```sql
-- 显示node表节点信息：
LIST NODE;
-- 显示节点名称为”db1”的节点信息：
LIST NODE db1;
-- 显示db1_2的master/slave节点信息：
list node datanode master db1_2;
-- 显示主机localhost1上的节点信息：
list node host localhost1;
```

### 4.5 param表相关命令
---

param表用于管理存放AntDB集群中所有节点的postgresql.conf文件中的参数，当参数某个被修改后，该参数就会被添加到此表中，用来标识。对于修改配置参数的查询，可以通过list param命令。

#### 4.5.1 set param

---
命令功能：
更改postgresql.conf节点配置文件中的参数，如果该参数有效，则系统内部会执行相关的操作，使更改生效，此操作只适用于那些不需要重启集群的参数类型（如sighup, user, superuser），而对于修改其它类型的参数，则会给出相应的提示。
如果在命令尾部加force，则不会检查参数的有效性，而强制写入文件中，系统不执行任何操作，只起到记录作用； 

**命令格式：**
```sql
SET COORDINATOR [ MASTER | SLAVE ] ALL ( { parameter = value } [, ...] ) [ FORCE ]
SET COORDINATOR { MASTER | SLAVE} node_name ( { parameter = value } [, ...] ) [ FORCE ]
SET DATANODE [ MASTER | SLAVE ] ALL ( { parameter = value } [, ...] ) [ FORCE ]
SET DATANODE { MASTER | SLAVE } node_name ( { parameter = value } [, ...] ) [ FORCE ]
SET GTM ALL ( { parameter = value } [, ...] ) [ FORCE ]
SET GTM { MASTER | SLAVE } node_name ( { parameter = value } [, ...] ) [ FORCE ]
```

**命令举例：**
```sql
-- 修改coord1上的死锁时间
SET  COORDINATOR  MASTER coord1(deadlock_timeout = '1000ms');
-- 修改所有的datanode上配置文件中的checkpoint_timeout的参数
SET  DATANODE  all(checkpoint_timeout = '1000s');
-- 修改所有的datanode上配置文件中的一个不存在的参数
SET  DATANODE  all(checkpoint = '10s')  FORCE;
```

#### 4.5.2 reset param
---
命令功能：
把postgresql.conf文件中的参数变为默认值。

**命令格式：**
```sql
RESET COORDINATOR [ MASTER | SLAVE ] ALL ( parameter [, ...] ) [ FORCE ]
RESET COORDINATOR { MASTER | SLAVE } node_name ( parameter [, ...] ) [ FORCE ]
RESET DATANODE [ MASTER | SLAVE ] ALL ( parameter [, ...] ) [ FORCE ] 
RESET DATANODE { MASTER | SLAVE } node_name ( parameter [, ...] ) [ FORCE ]
RESET GTM ALL ( parameter [, ...] ) [ FORCE ] 
RESET GTM { MASTER | SLAVE } node_name ( parameter [, ...] ) [ FORCE ]
```

**命令举例：**
```sql
-- 把datanode master db1的配置参数checkpoint_timeout变为默认值。其中查询结果中的*号是适配符，表示所有满足条件的节点名。
RESET  DATANODE  MASTER  db1 (checkpoint_timeout);
-- 把datanode中所有的配置参数checkpoint_timeout变为默认值
RESET  DATANODE  all (checkpoint_timeout);
```
#### 4.5.3 list param
---
命令功能：
查询节点的postgresql.conf配置文件中修改过的参数列表。

**命令格式：**
```sql
LIST PARAM
LIST PARAM node_type node_name [ sub_like_string ]
LIST PARAM cluster_type ALL [ sub_like_string ]

where node_type can be one of:

    GTM MASTER
    GTM SLAVE
    COORDINATOR MASTER
    COORDINATOR SLAVE
    DATANODE MASTER
    DATANODE SLAVE

where cluster_type can be one of:

    GTM
    COORDINATOR
    DATANODE
    DATANODE MASTER
    DATANODE SLAVE
```

**命令举例：**
```sql
--查询节点类型为datanode master ，节点名为db1配置文件中修改后的参数
LIST  param  DATANODE  MASTER  db1;
--查询节点类型为coordinator的所有节点中配置文件中修改后的参数
LIST  param  COORDINATOR  all;
```

#### 4.5.4 show

---

命令功能：
	显示配置文件中的参数信息，支持模糊查询。

**命令格式：**
> SHOW node_name parameter

**命令举例：**
```sql
-- 模糊查询节点db1的配置文件中有wal的参数
  SHOW  db1  wal;
-- 查询节点db1的配置文件中checkponit_timeout的参数的内容
  SHOW  db1  checkpoint_timeout;
```
### 4.6 hba表相关命令
---
hba表用于管理存放AntDB集群中所有coordiantor节点的pg_hba.conf文件中的配置项，当配置项被添加后，就会记录到此表中，用来标识。对于添加过的配置项，可以通过list hba命令显示。

#### 4.6.1 add hba

命令功能：
	添加新的hba配置到coordinator中。通过 \h add hba 获取帮助信息。

**命令格式：**
```sql
ADD HBA { ALL | coord_name } ( "hba_value" [, ...] )

where hba_value must be the following:

    host database user IP-address IP-mask auth-method
```

**命令举例：**
```sql
-- 在hba中添加 10.0.0.0 IP端的所有用户通过md5认证访问所有数据库的配置：
add hba all ("host all all 10.0.0.0 8 md5");
```
#### 4.6.2 list hba
---
命令功能：
	显示通过add hba添加的配置项。

**命令格式：**
>LIST HBA [ coord_name [, ...] ]

**命令举例：**
```sql
	postgres=# list hba;
 nodename |          hbavalue           
----------+-----------------------------
 coord1   | host all all 10.0.0.0 8 md5
 coord2   | host all all 10.0.0.0 8 md5
 coord3   | host all all 10.0.0.0 8 md5
 coord4   | host all all 10.0.0.0 8 md5
(4 rows)
```

#### 4.6.3 drop hba
---
命令功能：
	删除通过add hba添加的配置项。

**命令格式：**
>DROP HBA { ALL | coord_name } [ ( "hba_value" [, ...] ) ]

**命令举例：**
```sql
-- 在hba中删除 10.0.0.0 IP端的所有用户通过md5认证访问所有数据库的配置：
drop hba all ("host all all 10.0.0.0 8 trust");
```
### 4.7 集群管理相关命令
---
对AntDB集群的管理主要包括启停、监控，初始化和清空等各种操作，对应的操作命令为start，stop，monitor，init和clean命令。下面对这些命令的功能和使用方法进行详细的解释。

#### 4.7.1 init all

---
命令功能：
初始化整个AntDB集群。Adbmgr 不提供单个节点初始化的命令，只提供对整个集群进行初始化的命令。通过往host表，node表中添加ADB集群所需要的host和node信息，只需要执行init all命令即可初始化并启动整个集群。具体功能可通过帮助命令 \h init all  查看。

**命令格式：**
>INIT ALL

**命令举例：**
```sql
-- 配置host表和node表后，初始化整个集群：
  INIT ALL;
```

#### 4.7.2 monitor
---
命令功能：
查看AntDB 集群中指定节点名字或者指定节点类型的运行状态。Monitor命令的返回值共有三种：
Running：指节点正在运行且接受新的连接；
Not running：指节点不在运行；
Server is alive but rejecting connections：指节点正在运行但是拒绝新的连接。
具体功能可通过帮助命令 \h monitor  查看。

**命令格式：**
```sql
MONITOR [ ALL ]
MONITOR GTM [ ALL ]
MONITOR GTM { MASTER | SLAVE } [ ALL | node_name ]
MONITOR COORDINATOR { MASTER | SLAVE } [ ALL | node_name [, ...] ]
MONITOR DATANODE [ ALL ]
MONITOR DATANODE { MASTER | SLAVE } [ ALL | node_name [, ...] ]
MONITOR AGENT [ ALL | host_name [, ...] ]
MONITOR HA
MONITOR HA [ ( option ) ] [ node_name [, ...] ]
```
**命令举例：**
```sql
-- 查看当前ADB集群中所有节点的运行状态：
MONITOR ALL;
-- 查看当前集群中所有coordinator节点的运行状态：
MONITOR COORDINATOR ALL;
-- 查看当前集群中节点类型为datanode master，节点名字为db1和db2的运行状态：
MONITOR DATANODE MASTER db1,db2;
-- 查看集群agent状态：
MONITOR agent ;
-- 查看集群流复制状态：
MONITOR ha;
```
#### 4.7.3 start
命令功能：
启动指定的节点名字的集群节点，或者启动指定节点类型的所有集群节点。具体功能可通过帮助命令 \h start  查看。

**命令格式：**
```sql
START ALL
START AGENT { ALL | host_name [, ...] } [ PASSWORD passwd ]
START GTM ALL
START GTM { MASTER | SLAVE } node_name
START COORDINATOR [ MASTER | SLAVE ] ALL
START COORDINATOR { MASTER | SLAVE } node_name [, ...]
START DATANODE ALL
START DATANODE { MASTER | SLAVE } { ALL | node_name [, ...] }
```

**命令举例：**
```sql
-- 启动集群中所有节点：
START ALL;
-- 启动gtm master节点：
START GTM MASTER gtm;
-- 启动当前集群中节点类型为datanode master，名字为db1和db2的节点：
START DATANODE MASTER db1,db2;
-- 启动集群主机上的agent：
START AGENT all;
```

#### 4.7.4 stop
---
命令功能：
此命令与start命令相反，停止指定名字的节点，或者停止指定节点类型的所有集群节点。
Stop命令如果没有指定MODE，默认使用smart模式。
Stop 模式有三种：smart ，fast和immediate。

- Smart：拒绝新的连接，一直等老连接执行结束。
- Fast：拒绝新的连接，断开老的连接，是比较安全的停止节点的模式。
- Immediate：所有数据库连接被中断，用于紧急情况下停止节点。

具体功能可通过帮助命令“\h stop” 查看。

**命令格式：**
```sql
STOP ALL [ stop_mode ]
STOP AGENT { ALL | host_name [, ...] }
STOP COORDINATOR [ MASTER | SLAVE ] ALL [ stop_mode ]
STOP COORDINATOR { MASTER | SLAVE } { node_name [, ...] } [ stop_mode ]
STOP DATANODE ALL [ stop_mode ]
STOP DATANODE { MASTER | SLAVE } { ALL | node_name [, ...] } [ stop_mode ]
STOP GTM ALL [ stop_mode ]
STOP GTM { MASTER | SLAVE } node_name [ stop_mode ]
where stop_mode can be one of:

    MODE SMART     | MODE S
    MODE FAST      | MODE F
    MODE IMMEDIATE | MODE I
```

**命令举例：**
```sql
-- 使用fast模式停止集群中所有节点：
STOP ALL MODE FAST;
-- 使用immediate模式停止所有coordinator节点：
STOP COORDINATOR ALL MODE IMMEDIATE;
-- 使用smart模式停止当前集群中节点类型为datanode master，名字为db1和db2的节点：
STOP DATANODE MASTER db1,db2; 或者
STOP DATANODE MASTER db1,db2 MODE SMART;	
-- 停止集群主机上的agent：
STOP AGENT all;
```
#### 4.7.5 append
命令功能：
Append命令用于向AntDB集群中追加集群节点，用于集群扩容。Gtm master是集群中的核心，append命令不包括追加gtm master命令。
执行append命令以前需要执行下面操作步骤(假设append coordinator到一台新机器上)：
- 1.把这台新机器的host信息添加到host表中。
- 2.把要追加的coordinator信息添加到node表中。
- 3.在新机器上创建用户及其密码。
- 4.执行deploy 命令把集群可执行文件分发到新机器上。
- 5.在新机器上修改当前用户下隐含文件bashrc，追加如下内容并执行source .bashrc使其生效：
```shell
export ADBHOME=/opt/antdb/app (以实际情况修改)
export PATH=$ADBHOME/bin:$PATH
export LD_LIBRARY_PATH=$ADBHOME/lib:$LD_LIBRARY_PATH
```
- 6.执行start agent，启动新机器上的agent 进程。
- 7.执行append命令。
具体功能可通过帮助命令 \h append  查看。

**命令格式：**
```sql
APPEND GTM SLAVE node_name
APPEND DATANODE { MASTER | SLAVE } node_name
APPEND COORDINATOR MASTER node_name

-- 利用流复制功能加快append coordinator
APPEND COORDINATOR dest_coordinator_name FOR source_coordinator_name
APPEND ACTIVATE COORDINATOR node_name
```

**命令举例：**
```sql
-- 往AntDB集群中追加一个名为coord4的coordinator节点：
APPEND COORDINATOR master coord4;
-- 往AntDB集群中追加一个名为db4的datanode master节点：
APPEND DATANODE MASTER db4;
-- 为AntDB集群中追加一个名为db4的datanode slave节点：
APPEND DATANODE SLAVE db4;
-- 利用流复制功能往AntDB集群中追加coordinator master 节点：
APPEND COORDINATOR coord5 FOR coord1; 
APPEND ACTIVATE COORDINATOR coord5;
```
#### 4.7.6 failover
---
命令功能：
当集群中的gtm/datanode master主节点出现问题的时候，可以通过此命令把备节点主机切换过来，保证集群的稳定性。

在主机存在问题等情况下，为保障服务的可持续性，可以通过failover命令操作将备机升为主机。具体功能可通过帮助命令 \h failover gtm  、 \h failover datanode 查看。

> 注意：
>
> failover命令不加”FORCE”则只允许备机为同步备机且运行正常才能升为master，否则报错；Failover命令加”FORCE”备机运行正常即可升为master。
>
> Failover命令通过节点信息验证sync_state列的值，选择其中的同步备机升为master，如无同步备机，使用force选项，则会选择xlog位置离master最近的异步备机提升为主。
>
> **如果通过加”FORCE”命令强制将异步备机升为主机，可能存在数据丢失风险。**

**命令格式：**
```sql
FAILOVER GTM node_name [ FORCE ]
FAILOVER DATANODE node_name [ FORCE ]
参数说明：
node_name:
节点名称，对应node表name列。
```

**命令举例：**
```sql
-- 将gtm master的同步备机升为主机：
FAILOVER GTM  gtm_1;
-- 将运行正常的异步备机gtm_1强制升为主机：
FAILOVER GTM gtm_1 FORCE;
-- 将datanode master db1的同步备机升为主机：
FAILOVER DATANODE db1;
-- 将运行正常的异步备机强制升为主机：
FAILOVER DATANODE  db1 FORCE;
```
#### 4.7.7 clean
---
命令功能：
Clean 命令用于清空AntDB 集群中节点数据目录下面的所有数据。执行此命令的前提是所有节点都处在stop 状态。执行clean命令不会有交互，所以如果需要保留数据，请慎重执行这个命令。先只支持clean all命令。
具体功能可通过帮助命令 \h clean  查看。

**命令格式：**
```
CLEAN ALL
CLEAN COORDINATOR { MASTER | SLAVE } { node_name [ , ... ] }
CLEAN DATANODE { MASTER | SLAVE } { node_name [ , ... ] }
CLEAN GTM { MASTER | SLAVE } node_name
CLEAN MONITOR number_days
```

**命令举例：**
```sql
-- 清空AntDB 集群中所有节点数据目录下的内容(ADB 集群处在stop状态)：
CLEAN ALL;
-- 清空coordinator节点数据目录：
CLEAN COORDINATOR MASTER coord1;
-- 清空15天前的monitor数据：
CLEAN MONITOR 15;
```

#### 4.7.8 deploy
---
命令功能：
Deploy 命令用于把Adbmgr所在机器编译的AntDB 集群的可执行文件向指定主机的指定目录上分发。常用于在刚开始部署AntDB集群或者AntDB 集群源码有改动，需要重新编译时。
具体功能可通过帮助命令 \h deploy  查看。

**命令格式：**
>DEPLOY { ALL | host_name [, ...] } [ PASSWORD passwd ]

**命令举例：**
```sql
-- 把可执行文件分发到所有主机上(host 表上所有主机)，主机之间没有配置互信，密码都是“ls86SDf79”：
DEPLOY ALL PASSWORD 'ls86SDf79';
-- 把可执行文件分发到所有主机上(host 表上所有主机)，主机之间已经配置互信：
DEPLOY ALL;
-- 把可执行文件分发到host1和host2主机上，两主机都没有配置互信，密码都是'ls86SDf79'：
DEPLOY host1,host2 PASSWORD 'ls86SDf79';
-- 把可执行文件分发到host1和host2主机上，两主机都已经配置互信：
DEPLOY host1,host2;
```

#### 4.7.9 adbmgr promote
---
命令功能：
在NODE表中更改指定名称的节点对应的状态为master,删除该节点对应的master信息；同时在PARAM表中更新该节点对应的参数信息。该命令主要用在执行FAILOVER出错后续分步处理中。具体功能可通过帮助命令“\h adbmgr promote” 查看。

**命令格式：**
>ADBMGR PROMOTE { GTM | DATANODE } SLAVE node_name

**命令举例:**
```sql
-- 更新adbmgr端node表及param表中datanode slave datanode1状态为master：
ADBMGR PROMOTE DATANODE SLAVE datanode1;
```
#### 4.7.10 promote
---
命令功能:
对节点执行PROMOTE操作，将备机的只读状态更改为读写状态，通过SELECT PG_IS_IN_RECOVERY()查看为f结果。该命令主要用在执行FAILOVER出错后续分步处理中。具体功能可通过帮助命令“\h promote gtm” 或者 “\h promote datanode”查看。

**命令格式：**
```
PROMOTE DATANODE { MASTER | SLAVE } { node_name }
PROMOTE GTM { MASTER | SLAVE } { node_name }
```

**命令举例：**
```sql
-- 将datanode slave datanode1提升为读写状态:
PROMOTE DATANODE SLAVE datanode1;
-- 将gtm slave gtm1提升为读写状态:
PROMOTE GTM SLAVE gtm1;
```
#### 4.7.11 rewind

---
命令功能:
对GTM或者DATANODE备机执行rewind操作，使其重建备机与主机的对应关系。

**命令格式：**
```
REWIND DATANODE SLAVE { node_name }
REWIND GTM SLAVE { node_name }
```

**命令举例：**
```sql
-- 重建备机datanode slave datanode1与master的关系:
REWIND DATANODE SLAVE datanode1;
-- 重建备机gtm slave gtm1与master的关系:
REWIND GTM SLAVE gtm1;
```



## 第五章 问题及解决方法

### 5.1 init all时报ERROR

---
- 问题：在init all 时会报如下错误：
ERROR:  character with byte sequence 0xe6 0x8b 0x92 in encoding "UTF8" has no equivalent in encoding "LATIN1"
- [x] 解决方法：
这种通常出现在AntDB 集群或者Adbmgr 安装在虚拟机中，可以通过命令locale查看当前配置：
```shell
$ locale
LANG=en_US.UTF-8
LC_CTYPE="en_US.UTF-8"
LC_NUMERIC="en_US.UTF-8"
LC_TIME="en_US.UTF-8"
LC_COLLATE="en_US.UTF-8"
LC_MONETARY="en_US.UTF-8"
LC_MESSAGES="en_US.UTF-8"
LC_PAPER="en_US.UTF-8"
LC_NAME="en_US.UTF-8"
LC_ADDRESS="en_US.UTF-8"
LC_TELEPHONE="en_US.UTF-8"
LC_MEASUREMENT="en_US.UTF-8"
LC_IDENTIFICATION="en_US.UTF-8"
```
查看变量LANG是否为en_US.UTF-8，若为空或者不是，只需把LANG配置为en_US.UTF-8即可。



## 第六章 附 录

**附录 A**

在编译Adbmgr或者编译AntDB 集群的过程中会报各种配置错误，这是由于Adbmgr需要这些库的支持，所以只需要安装对应的库即可。下面是常见报错及解决方法。
### 5.1.1 configure阶段常见报错及解决方法
---
- 报错：configure: error: readline library not found
- [x]  解决办法：yum -y install readline-devel
- 报错：configure: error: zlib library not found
- [x] 解决办法：yum -y install zlib-devel
- 报错：configure: error: library 'crypto' is required for OpenSSL
- [x] 解决办法：yum -y install openssl openssl-devel
- 报错：configure: error: library 'pam' is required for PAM
- [x] 解决办法：yum -y install pam pam-devel
- 报错：configure: error: library 'xml2' (version >= 2.6.23) is required for XML support
- [x] 解决办法：yum -y install libxml2 libxml2-devel
- 报错：configure: error: library 'xslt' is required for XSLT support
- [x] 解决办法：yum -y install libxslt libxslt-devel
- 报错：configure: error: header file is required for LDAP
- [x] 解决办法：yum -y install openldap openldap-devel
- 报错：configure: error: header file <Python.h> is required for Python
- [x] 解决办法：yum -y install python python-devel
- 报错： libssh2.h: No such file or directory
- [x] 解决办法： yum -y install libssh2-devel
- 报错：configure: error: could not determine flags for linking embedded Perl.
- [x] 解决办法：yum install perl-ExtUtils-Embed

### 5.1.2 make 阶段常见报错及解决方法

---
- 报错：ERROR: `flex' is missing on your system.
- [x] 解决办法：yum -y install flex flex.x86_64
- 报错：ERROR: `bison' is missing on your system.
- [x] 解决办法：yum -y install bison bison-devel
