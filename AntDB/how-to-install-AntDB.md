# 快速安装AntDB

AntDB（为了方便后续都简称为ADB）集群，有单独的一个管理模块（ADB manger）来管理，监控和维护。详细信息可以参考《ADB集群管理工具(ADB manager)使用手册.md》。下面就简单介绍下如何通过ADB manager快速部署ADB 集群。
## 第一章 初始化ADB manger

### 1.1 源码安装ADB manager
---
ADB manager与ADB 集群的源码绑定在一起，所以编译ADB manager，就是编译ADB 集群的源码。

编译前需要提前使用root权限安装好如下依赖包：
```shell
yum install -y perl-ExtUtils-Embed
yum install -y flex
yum install -y bison
yum install -y readline-devel
yum install -y zlib-devel
yum install -y openssl-devel
yum install -y pam-devel
yum install -y libxml2-devel
yum install -y libxslt-devel
yum install -y openldap-devel
yum install -y python-devel
yum install -y gcc-c++ 
yum install -y libssh2
```

接着就可以进行编译安装步骤：

- step 1: cd 进入源码目录
- step 2: ./configure ==--prefix=/opt/adbsql== --with-perl --with-python --with-openssl --with-pam --with-ldap --with-libxml --with-libxslt --enable-thread-safety --enable-debug --enable-cassert CFLAGS="-DWAL_DEBUG -O0 -ggdb3"
- step 3: make install-world-contrib-recurse

**注:** step 2步骤中，--prefix目录为准备安装的目录，可以根据需求灵活设置。
### 1.2 RPM安装 ADB manager
---
通过交付人员提供的rpm包来安装（root用户执行）：
```shell
rpm -ivh adb-2.2.703602c-10.el7.centos.x86_64.rpm
```
注：在执行rpm安装之前，需要找ADB交付人员咨询rpm包的安装路径。

### 1.3初始化ADB manager
---
**新建一个普通的用户：adb（或者使用已有的普通用户），初始化ADB manager。**
编译ADB manager之后，会在指定的目录的bin目录下产生initmgr和mgr_ctl可执行文件。

为了使用方便，初始化ADB manager还需要配置PATH变量。
执行**vim ~/.basrhrc**打开文件，追加如下内容：
```shell
export ADBHOME=/opt/adbsql 
export PATH=$ADBHOME/bin:$PATH
export LD_LIBRARY_PATH=$ADBHOME/lib:$LD_LIBRARY_PATH
```
然后执行source .bashrc 使其生效即可。

执行下面命令开始初始化ADB manager：
```shell
initmgr –D /data/adb/mgr
```


### 1.4启动 ADB manager
---
ADB manager初始化成功后，就可以启动它了。有如下两种启动方式，可以任选一种执行。

- **mgr_ctl start -D /data/adb/mgr**
- **adbmgrd -D /data/adb/mgr &**

注：
- 1、为了防止端口冲突,启动前将配置文件中(mgr/postgresql.conf)默认的port=6432修改为未被占用的端口，示例中设置port=10090;
- 2、/data/adb/mgr要与初始化路径保持一致。

## 第二章 搭建ADB 集群

如何使用ADB manager快速搭建ADB 集群？
通过如下命令可以登录到ADB manager上，下面的所有操作都是通过ADBmanger来操作：
>psql -d postgres -p 10090 

```shell
[gd@INTEL175 ~]$ psql -d postgres -p 10090                              
psql (ADB 3.0 based on PG 9.6.2 ADB 3.1devel 7fb79fd9d3)
Type "help" for help.

postgres=# 
```

### 2.1 添加主机(host)
---
添加命令|	add host 主机名(address, agentport,user,adbhome);
--|--
**查看命令**|	list host;

部分参数可以不写，有默认值， 例如port默认22，user默认值是当前用户;

**举例：**
```sql
add host localhost1(port=22,protocol='ssh',adbhome='/opt/adbsql',address="10.1.226.201",agentport=8432,user='adb');
add host localhost2(port=22,protocol='ssh',adbhome='/opt/adbsql',address="10.1.226.202",agentport=8432,user='adb');
add host localhost3(port=22,protocol='ssh',adbhome='/opt/adbsql',address="10.1.226.203",agentport=8432,user='adb');
```

### 2.2 deploy二进制程序
---
deploy命令会将ADB的二进制执行文件打包发送到host表中所有主机上。对于第一次部署集群，或者集群的安装包有更新，为了集群安装的稳定性，则应首先手动清空集群下所有主机的执行文件。
在集群内各主机之间如果没有设置互信的情况下，执行deploy all需要输入用户密码（当前用户的登录密码），如果设置主机间互信，则可以省去密码的繁琐设置。
**命令：**
一次部署所有主机|	deploy all password 'adb';
---|---
**部署指定的主机**	|**deploy localhost1,localhost2 password 'adb';**

### 2.3 启动agent
---
有两种方式：一次启动全部agent和单独启动一台主机agent（多个主机需要多次执行）。

注意：password是host表中主机user对应的linux系统密码，用于与主机通信，而非ADB的用户密码。
当密码是以数字开头时，需要加上单引号或者双引号，例如password ‘12345z’是正确的，password 12345z则会报错；如果密码不是以数字开头，则加不加引号都行。

一次启动全部agent|	start agent all  password 'adb';
---|---
**启动指定的agent**	|**start agent localhost1/localhost2 password 'adb';**

当密码不对，启动agent失败时，报错如下：
```shell
postgres=# deploy localhost3 password '123456';    
  hostname  | status |                description                
------------+--------+-------------------------------------------
 localhost3 | f      | Authentication failed (username/password)
(1 row)
```

### 2.4 配置集群节点
---
Node表中添加gtm、coordinator、datanode master、datanode slave等节点信息。
注意：host名称必须来自host表，端口号不要冲突，path指定的文件夹下必须为空，否则初始化将失败并报错。这种设置，是防止用户操作时，忘记当前节点下还有有用的数据信息。

**添加命令：**
add节点 | command
---|---
添加coordinator信息|add coordinator 名字(path = 'xxx', host='localhost1', port=xxx);
添加datanode master信息|add datanode master 名字(path = 'xxx', host='localhost1', port=xxx);
添加datanode slave和extra信息，从节点与master同名，所以同名的master必须存在，同异步关系通过sync参数设置|add datanode slave名字(host='localhost2', port=xxx, path='xxx', sync=t);add datanode extra名字(host='localhost2', port=xxx, path='xxx', sync=f);
添加gtm信息，从节点必须与主节点同名|add gtm master名字(host='localhost3',port=xxx, path='xxx');add gtm slave名字(host='localhost2',port=xxx, path='xxx');add gtm extra名字(host='localhost1',port=xxx, path='xxx');

添加完成后，使用命令list node查看刚刚添加的节点信息

**举例：（gtm/datanode 均为一主一从）**
```sql
add coordinator coord0(path = '/data/adb/adb_data/coord/0', host='localhost1', port=4332);
add coordinator coord1(path = '/data/adb/adb_data/coord/1', host='localhost2', port=4332);
add datanode master datanode0(path = '/data/adb/adb_data/datanode/0', host='localhost1', port=14332);
add datanode slave datanode0(host='localhost2',port=14332,path='/data/adb/adb_data/datanode/00');
add datanode master datanode1(path = '/data/adb/adb_data/datanode/1', host='localhost2', port=24332);
add datanode slave datanode1(host='localhost1',port=24332,path='/data/adb/adb_data/datanode/11');
add gtm master gtm(host='localhost3',port=6655, path='/data/adb/adb_data/gtm');
add gtm slave gtm(host='localhost2',port=6655,path='/data/adb/adb_data/gtm_slave');
```

### 2.5 配置节点参数
---
**set param:**

同时设置所有同类型节点：
>set datanode|coordinator|gtm all(key1=value1, key2=value2...); 

设置某一个节点的参数:

>set{datanode|coordinator|gtm} {master|slave|extra} {nodename|all} (key1=value1, key2=value2...);

注意：相同的参数，slave的参数必须大于等于master，否则启动失败，查看log如下：
> 2017-10-17 10:50:55.730 CST 22023 0FATAL:  hot standby is not possible because max_prepared_transactions = 100 is a lower setting than on the master server (its value was 150)

**举例：**
```sql
--设置coordinator的最大连接数
set coordinator all (max_connections=800);
SET PARAM
```
**注**:用户可以根据需求灵活设置参数，也可以手动到单个节点的数据目录修改单节点的参数配置文件

**reset param:**

reset参数：
>reset {datanode|coordinator|gtm} {master|slave|extra} {nodename|all} (key1,key2...); （key,...） ；也可以支持 （key=value,key2,...），不过此时value值没有作用。
若parm表中存在参数设置，则删除

### 2.6 init all启动集群
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
 nodename |    nodetype     | status | description |     host     | port  
----------+-----------------+--------+-------------+--------------+-------
 coord1   | coordinator     | t      | running     | 10.1.226.201 |  4332
 coord2   | coordinator     | t      | running     | 10.1.226.202 |  4332
 db1      | datanode master | t      | running     | 10.1.226.201 | 14332
 db1      | datanode slave  | t      | running     | 10.1.226.202 | 14332
 db2      | datanode master | t      | running     | 10.1.226.202 | 24332
 db2      | datanode slave  | t      | running     | 10.1.226.201 | 24332
 gtm      | gtm master      | t      | running     | 10.1.226.203 |  6655
 gtm      | gtm slave       | t      | running     | 10.1.226.202 |  6655
(6 rows)
```
**至此，ADB集群初始化完成！**