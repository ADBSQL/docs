# AntDB FAQ

AntDB 常见问题解答 

## 安装配置

***

###  package antdb-4.0-1.el7.centos.x86_64 is already installed

**解决方式** 

服务器已经安装了该RPM包。
请以升级方式安装 或 先卸载后再安装。
具体说明见后面的 RPM 安装卸载相关说明

```
--查询已安装的antdb RPM包
[root@cos01 ~]# rpm -qa antdb
antdb-4.0-1.el7.centos.x86_64
--查询RPM包的详细信息：安装时间、安装路径等
[root@cos01 ~]# rpm -qi antdb-4.0-1.el7.centos.x86_64
Name        : antdb
Version     : 4.0
Release     : 1.el7.centos
Architecture: x86_64
Install Date: Sat 18 Feb 2017 02:34:47 PM CST
Group       : Applications/Internet
Size        : 45039454
License     : GPL
Signature   : (none)
Source RPM  : antdb-4.0-1.el7.centos.src.rpm
Build Date  : Sat 18 Feb 2017 01:33:04 PM CST
Build Host  : cos01
Relocations : /usr 
URL         : none
Summary     : ADB
Description :
adb2.2 build at 20170217.
--列出RPM包含哪些文件，详细清单信息
[root@cos01 ~]# rpm -ql antdb-4.0-1.el7.centos.x86_64
/opt/antdb
/opt/antdb/bin
/opt/antdb/lib
/opt/antdb/share
/opt/antdb/include

--某个程序是哪个软件包安装的，或者哪个软件包包含这个程序
    rpm -qf `which 程序名`    #返回软件包的全名
    rpm -qif `which 程序名`   #返回软件包的有关信息
    rpm -qlf `which 程序名`   #返回软件包的文件列表

--安装RPM
[root@cos01 ~]# rpm -ivh adb-4.0-1.el7.centos.x86_64
--以升级方式安装RPM
[root@cos01 ~]# rpm -Uvh adb-4.0-1.el7.centos.x86_64
--卸载RPM
[root@cos01 ~]# rpm -e antdb
```
**原因说明**

服务器已经安装了该RPM包。

***

###  error: library 'crypto' is required for OpenSSL

**解决方式** 

RPM包未安装。

```
yum install openssl openssl-devel
```
**原因说明**

在安装AntDB时，需要一些系统的依赖包。
如出现类似错误，按上述方式以root用户安装即可。
完整的依赖包如下：

```
yum install perl-ExtUtils-Embed flex bison readline-devel zlib-devel openssl-devel pam-devel libxml2-devel libxslt-devel openldap-devel python-devel libssh2-devel
```

***

###  rpm: relocations must begin with a /

**解决方式** 

在使用antdb提供的rpm包安装程序时，
若不指定安装路径，则默认安装在/opt/app/adb(或/opt/app/antdb)目录。
但客户一般都要求安装至指定目录，那么可以使用rpm命令提供的relocate选项，
将默认安装路径调整至指定目录。
(以/data/sy/adb40sy/adb指定目录为例)

```
sudo rpm -ivh adb-4.0.9ff827a8-10.el7.centos.x86_64.rpm --relocate=/opt/app/adb=$ADB_HOME
注：relocate和后面的配置之间，不要有空格。若存在空格，则抛出标题所示的错误信息
```
**原因说明**

relocate和value之间不要添加空格。

***

###  LOG:  invalid value for parameter "max_stack_depth": 16384

**解决方式** 

登录服务器，修改/etc/security/limits.conf，增加用户的栈深度大小：
(以antdb用户为例)

```
antdb soft stack unlimited
antdb hard stack unlimited
```
**原因说明**

一个数据库进程在运行时的STACK所占的最大安全深度。若发现不能正常运行一个复杂的递归操作或一个复杂函数，建议适当提高该配置的值。

***


###  ERROR:  unrecognized configuration parameter "shared_buffers"

**解决方式** 

登录adbmgr，执行下述命令：

```
flush param;
```
**原因说明**

部分场景下，由于adbmgr的param信息未被初始化，手工执行上述命令初始化之后，再set参数即可。

***

###  error while loading shared libraries: libpq.so.5: cannot open shared object file: No such file or directory

**解决方式** 

.bashrc 环境变量中，是否设置了如下环境变量LD_LIBRARY_PATH

```
export LD_LIBRARY_PATH=$ADB_HOME/lib:$LD_LIBRARY_PATH
```
**原因说明**

某些特殊软件或插件，只识别.bashrc而不识别 .bash_profile，添加后退出终端重新登录。

***

###  Authentication failed (username/password)

**解决方式** 

各主机之间是否配置了互信。
或在命令后添加 password'xxxx'选项。
下面给出一个示例说明：

```
postgres=# start agent all;
 hostname | status |                description                
----------+--------+-------------------------------------------
 antdb01  | f      | Authentication failed (username/password)
 antdb02  | f      | Authentication failed (username/password)
(2 rows)

postgres=# 
postgres=# start agent all password'123';
 hostname | status | description 
----------+--------+-------------
 antdb01  | t      | success
 antdb02  | t      | success
(2 rows)
```
**原因说明**

AntDB的mgr通过ssh远程管理各节点，因此需配置ssh互信或添加password选项。

***

###  FATAL:  could not create shared memory segment: Cannot allocate memory

**解决方式** 

shared_buffer设置不合理，超出了kernel.shmmax 的系统配置。
建议减小shared_buffer值，
或增大内核参数，如shmall、shmmax值。
如果设置超大，大过内存值，则直接报错Invalid argument。
FATAL:  invalid value for parameter "shared_buffers": "222222GB"
HINT:  Value exceeds integer range.

**原因说明**

按上述方式调整配置。

***

###  FATAL:  could not create semaphores: No space left on device

**解决方式** 

max_connections设置不合理，超出了kernel.sem的系统配置。 
max_connections是最大连接数，即允许客户端连接的最大连接数，增大连接可以允许接入更多的客户端，但设置过大同样会造成DB启动失败 
semget是获取信号的一个函数，即get semaphore。
上述的空间不够不是指的是磁盘空间不够，而是创建semaphores时空间参数不够，系统调用参数semget报错，但是错误信息感觉有些迷惑......
解决办法通常是减小max_connections，或者增大内核参数，如semmni、semmns等


**原因说明**

按上述方式调整配置。

### libpqwalreceiver.so: undefined symbol: PQconninfo

在slave上可能会出现这个报错。
原因是在主机上安装了操作系统镜像中的`postgresql` 相关RPM包，与AntDB的有冲突。

**解决方式** 

卸载操作系统镜像中的 `postgresql` 相关RPM包：
```shell
sudo rpm -e postgrsql*
```

### unable to exchange encryption keys

集群版本中启动agent的时候，可能会出现这个报错，原因是：libssh2的版本过低，可通过升级libssh2版本解决。

可以通过源码编译安装 libssh2 ：
- 下载地址：https://www.libssh2.org/，备份地址：http://120.55.76.224/files/libssh2/
- 源码编译安装(root 执行)

```
wget https://www.libssh2.org/download/libssh2-1.9.0.tar.gz
tar xzvf libssh2-1.9.0.tar.gz
cd libssh2-1.9.0
./configure
make
make install
```

提供一个C代码检查libssh2版本：
```c
#include <stdio.h>
#include <libssh2.h>

int main ()
{
    printf("libssh2 version: %s\n", LIBSSH2_VERSION );
}
```
保存为 ： check_libssh2.c 

编译： `gcc check_libssh2.c -o check_libssh2`
执行： `./check_libssh2`
预期的输出为：
```
libssh2 version: 1.9.0
```



***

## 数据库连接

***

###  FATAL:  database "cz" does not exist

**解决方式** 

未指定数据库实例名。
psql 需要指定 -d 选项 或 在环境变量添加 PGDATABASE=xxx

```
psql -d shcrm -p xxx -U xxx
```

**原因说明**

psql连接时，若不指定数据库名称，则以下述顺序优先选择：
环境变量 $PGDATABASE > psql登录时的用户名 
若上述2个配置名称在数据库中均不存在，则抛出高错误。

***

###  psql: could not connect to server: Connection refused

**解决方式** 

未指定数据库主机IP。
psql 需要指定 -h 选项 或 在环境变量添加 PGHOST=x.x.x.x

```
psql -h xxx -d xxx -p xxx -U xxx
```

**原因说明**

无

***

###  psql: could not connect to server: No such file or directory

**解决方式** 

未指定数据库监听端口。
psql 需要指定 -p 选项 或 在环境变量添加 PGPORT=xxx

```
psql -p xxx -d xxx -U xxx
```

**原因说明**

无

***

###  FATAL:  role "cz" does not exist

**解决方式** 

未指定数据库连接用户名。
psql 需要指定 -U 选项 或 在环境变量添加 PGUSER=xxx

```
psql -U xxx -d xxx -p xxx
```

**原因说明**

无

***

###  psql: could not connect to server: Connection refused

**解决方式** 

为安全起见，默认禁用了远程连接访问功能，只允许localhost连接。那么，如何启用该功能呢?
为了启用网络或者远程访问功能，我们需要在postgresql.conf文件中添加或者编辑下列内容：
　　`listen_addresses = '*'`
在pg_hba.conf添加如下内容，以便允许用户通过某种method来访问数据库：

```
# TYPE DATABASE USER CIDR-ADDRESS METHOD

host all all 10.20.21.0/24 trust
```

postgresql.conf

|配置项|说明|
|:--|:--|
|listen_addresses = '*'|listen_addresses指定了要侦听的IP地址。默认只监听localhost的地址，也就是禁止远程服务器来访问。在大多数情况下，我们会接受所有主机的连接，所以可以使用“*”，它表示所有IP地址。如果只接受指定ip的连接，则在pg_hba.conf进行配置。|

pg_hba.conf

|配置项|说明|
|:--|:--|
|TYPE|Type = host表示远程连接。Type = local表示本地Unix domain socket连接。|
|DATABASE|Database = all 表示所有数据库。其他名字要求严格匹配，还可以规定一个由逗号分隔的数据库列表。|
|USER|User = all 表示所有用户。其他名字要求严格匹配，还可以规定一个由逗号分隔的用户列表。|
|CIDR-ADDRESS|CIDR-ADDRESS 由两部分组成，即IP地址/子网掩码。子网掩码规定了IP地址中前面哪些位表示网络编号。这里/0表示IP地址中没有表示网络编号的位，这样的话全部的IP地址都匹配，例如192.168.0.0/24表示匹配前24位，所以它匹配任何192.168.0.x形式的IP地址。|
|METHOD|Method = trust表示可信认证，允许免密登录。其他的认证方法包括MD5，则要求客户端输入密码验证才能访问数据库|

其他的一些可能的原因，如下：
* 服务端没起来，ps -ef|grep postgres查看是否存在postgres进程 
* 监听问题，cat postgresql.conf|grep listen 查看监听地址是否正确 
* 以上都没问题，服务器端能连进去，但客户端不行，这时需要查看pg_hba.conf
* 以上都没问题，检查服务器端的iptables,开启防火墙的访问端口
* 以上都没问题，检查SELINUX，确保SELINUX已关闭

**原因说明**

按上述说明依次排查

***


###  Fatal:connection limit exceeded for non-supersers

**解决方式** 

数据库连接数达到上限，需要调整最大连接数配置。

max_connections是数据库允许的最大连接数，默认值100， 
superuser_reserved_connections是预留给超级用户的连接数，默认值3 
修改这两个参数都需要重启DB。 
与之相关联的参数还有work_mem,连接数*work_mem可以得到DB的内存大小，这个调整视服务器的内存大小


**原因说明**

按上述说明增大max_connections的配置，并重启数据库服务生效。

###  FATAL:  password authentication failed for user "his"

**解决方式** 

请检查输入的密码是否正确？
此处的密码指该用户his在数据库中对应的密码，非操作系统登录密码。

**原因说明**

密码不正确，请确认密码的正确性。

***

###  FATAL:  no pg_hba.conf entry for host "10.21.28.35", user "adb01", database "postgres", SSL off

**解决方式** 

**AntDB单机版本：**

pg_hba.conf添加一行可信任配置：

```
host all all 10.21.28.0/24 md5
```

重新加载配置即可。其中 `10.21.28.0`  需要访问数据库的客户端IP网段。

```
pg_ctl -D /data/pgxc_data/cd1/  reload
```

> -D  后面的参数为数据目录。

reload执行成功后，重新尝试登录。

> 建议在主备环境上都执行下，防止主备切换后应用无法连接现在的备节点。

**AntDB集群版本：**
登录adbmgr执行下述命令即可：

```
add hba coordinator all("host all all 10.21.28.0 24 md5");
add hba gtmcoord all("host all all 10.21.28.0 24 md5");
```

> 示例中的IP根据实际情况进行修改。
>
> 如果执行报错，通过`\h add hba`可查看帮助信息。

执行成功后，重新尝试登录。

**原因说明**

节点的pg_hba.conf未配置该IP信息。

***

###  pg_ctl: could not open PID file "/ssd/adb40sy/data/cd/pg_hba.conf/postmaster.pid": Not a directory

**解决方式** 

通过pg_ctl reload重新加载配置文件时，只需要指定 -D ，即数据库的数据目录，勿需指定到具体的配置文件。
程序会自动重新加载改动后的配置信息。
以下给出一个示例说明：

```
--错误的方式
pg_ctl -D /ssd/adb40sy/data/cd/pg_hba.conf reload
--正确的方式
pg_ctl -D /ssd/adb40sy/data/cd/ reload
```
**原因说明**

pg_ctl reload -D 指定数据目录路径即可，勿需指定到某个具体的配置文件。

***

###  cached plan must not change result

**解决方式** 

在jdbc连接串中禁用prepareThreshold功能即可。
以下给出一个示例说明：

```
jdbc:postgresql://10.78.187.107:5432/postgres?binaryTransfer=False&forceBinary=False&grammar=oracle&prepareThreshold=0
```
**原因说明**

执行计划会在服务端被缓存起来，以降低重新生成执行同样计划的开销。
但若在运行过程中更改了表结构，则JDBC就会抛出该异常。
在jdbc连接串中 添加 prepareThreshold=0，禁用jdbc的该功能即可。默认prepareThreshold设置为5.

***

## 使用相关

***

###  psql:/unibss/dmp/hqy/gprs4/DR_GPRS_201812_A_P1_1.sql:18895: invalid command \N

**解决方式** 

由于psql批量导入时，刷新速度太快，该错误信息并非最原始的错误。
添加-v ON_ERROR_STOP=1选项，即可看到最原始的错误信息。

```
psql -p xxx -d xxx -f xxx.sql -v ON_ERROR_STOP=1
```
**原因说明**

产生该错误的原因较多。如 psql导入的表结构未创建、表上某列存在自增序列却没有创建。
请结合上述参数重新执行psql导入后，确认原始错误信息后，对症下药即可。

***

###  ERROR:  pg_basebackup: could not receive data from WAL stream: server closed the connection unexpectedly

pg_log报错信息：terminating walsender process due to replication timeout

**解决方式** 

1. 测试备机ssh至主机能否成功

```
ssh datanode_master_ip -p ssh_port
```
若调通ssh登录后，仍然失败，则进行步骤2的排查

2. 测试备机psql至主机能否成功

```
psql -p datanode_master_port -h master_ip -d replication
```

若调通psql登录后，仍然失败，则进行步骤3的排查

3. 测试备机psql至主机能否成功

wal_sender_timeout 由默认的60s调整为0. (0 没有时间限制)

wal_sender_timeout参数说明：
服务端会中断那些停止活动超过该配置的复制连接。
这对发送服务器检测一个备机崩溃或网络中断有用。
设置为0将禁用该超时机制。
该参数只能在postgresql.conf文件中或在服务器命令行上设置。默认值是 60 秒。

4. 其他可能相关配置项

```
--提升wal_keep_segments，由128调整至1024
wal_keep_segments = 1024
--打开归档模式
archive_mode = "on"
archive_command = "rsync -a %p /data2/antdb/data/arch/dn1/%f"

```

**原因说明**

产生原因较多，请按上述步骤依次排查。

***


###  ERROR:  cannot execute INSERT in a read-only transaction

**解决方式** 

antdb的datanode节点，默认只有读权限，只有coordinator具有读写权限。
这里psql连接的是datanode，而不是coordinator，可以让psql指定端口选项-p。
也可能配置了pgport的环境变量，如果配了pgport的环境变量，psql默认连到环境变量指向的那个端口。

```
psql -p xxx -d xxx -f xxx.sql -v ON_ERROR_STOP=1
```
**原因说明**

按上述说明依次排查

***

###  LOG: checkpoints are occurring too frequently

**解决方式** 

在数据库繁忙时，导致XLOG还没被应用，就被数据库重复使用写入数据。
AntDB4.0前(checkpoint_segments设置过小)
AntDB4.0后(max_wal_size设置过小)

```
AntDB4.0前(增加checkpoint_segments设置，>=128)
AntDB4.0后(增加max_wal_size设置，>=4GB)
```
**原因说明**

无

***

###  LOG: archive command failed with exit code (X)

**解决方式** 

硬盘空间不足或归档路径不存在
或用户没有写权限
或用户ssh或scp或rsync命令执行失败

**原因说明**

按上述说明依次排查

***

###  LOG: number of page slots needed (X) exceeds max_fsm_pages (Y)

**解决方式** 

max_fsm_pages最大自由空间映射不足。
建议增加max_fsm_pages的同时进行VACUUM FULL

**原因说明**

max_fsm_pages最大自由空间映射不足

***

###  ERROR: current transaction is aborted, commands ignored until end of transaction block

**解决方式** 

业务在代码中捕获该异常，并手工执行一次rollback操作。
或断开该连接后重新建链即可。
下面给出一个示例说明：

```
postgres=# begin;
BEGIN
postgres=# select * from sy01;
                  id                  
--------------------------------------
 adc8775e-4539-4861-9454-ceae45c568f7
(1 row)

postgres=# select * from sy011;
ERROR:  relation "sy011" does not exist
LINE 1: select * from sy011;
                      ^
postgres=# select * from sy011;
ERROR:  current transaction is aborted, commands ignored until end of transaction block
postgres=# rollback ;
ROLLBACK
postgres=# begin;
BEGIN
postgres=# select * from sy01;
                  id                  
--------------------------------------
 adc8775e-4539-4861-9454-ceae45c568f7
(1 row)

postgres=# commit;
COMMIT
```

**原因说明**

AntDB区别于oracle的设计，不会在发生异常后自动回滚。需用户手工执行一次回滚操作即可。
手工回滚后复用该连接就不会报错了。

***

###  ERROR:  operator does not exist: character = integer

**解决方式** 

Postgresql8.3以后取消了数据类型隐式转换，因此比较的数据类型需要一致。
AntDB兼容了2种语法模式：默认的postgres和兼容的oracle。 
oracle语法模式下，AntDB已经自研兼容了部分数据类型隐式转换的场景，包括该问题的场景已经兼容。
postgres语法模式下，依然会报该错误。
下面给出一个示例说明：

```
postgres=# \d sy02
            Table "public.sy02"
 Column |         Type          | Modifiers 
--------+-----------------------+-----------
 id     | character varying(10) | 

postgres=# set grammar TO postgres;
SET
postgres=# select count(*) from sy02 where id=123;
ERROR:  operator does not exist: character varying = integer
LINE 1: select count(*) from sy02 where id=123;
                                          ^
HINT:  No operator matches the given name and argument type(s). You might need to add explicit type casts.
postgres=# set grammar TO oracle;
SET
postgres=# select count(*) from sy02 where id=123;
 count 
-------
     0
(1 row)
```

**原因说明**

为了兼容oracle语法，AntDB自研兼容了较大部分的oracle数据类型隐式转换的场景。
建议优先尝试使用oracle语法模式。

***

###  canceling statement due to lock timeout

**解决方式** 

某一个长事务占用的锁尚未释放，新的个事务又申请相同对象的锁。
当达到lock_timeout设置的时间后，就会报这个错误。
客户端需要及时提交或回滚事务，长事务是非常消耗数据库资源的一种行为，请尽量避免。

```
--查看锁表情况
select locktype,relation::regclass as relation,virtualxid as vxid,transactionid as xid,virtualtransaction vxid2,pid,mode,granted from pg_locks where granted = 'f';
--查看执行时间大于5分钟的长事务
select datname,pid,usename,client_addr,query,backend_start,xact_start,now()-xact_start xact_duration,query_start,now()-query_start query_duration,state from pg_stat_activity where state<>$$idle$$ and now()-xact_start > interval $$5 min$$ order by xact_start;
--kill 长事务。2种方式如下（PID是上述sql语句查询出来的pid返回值）：
方法一：
SELECT pg_cancel_backend(PID);
这种方式只能kill select查询，对update、delete 及DML不生效)

方法二：
SELECT pg_terminate_backend(PID);
这种可以kill掉各种操作(select、update、delete、drop等)操作

```

如果在 `pg_locks` 中没有查到表相关的锁信息， 那么需要去各个 `datanode` 上查看是否有两阶段未完成的事务挂在那，查询视图：`select * from pg_prepared_xacts;`
根据 `prepared` 字段的时间值判断是否有异常的事务，所谓的异常，满足以下条件：
* `prepared` 字段值显示的时间距离当前时间较长，比如超过单个语句预期的执行时间。
* 每次查询，始终是某些事务，一直存在。

一般来说，这些事务算是异常事务了。可以在各个节点上查询这个事务的状态：`select pg_xact_status(50996670) ; ` ，参数值为 `pg_prepared_xacts` 中的 `gid` 值去掉 `T`。

* 如果事务在 `GTMCOORD` 上已经提交，则需要在本节点提交该事务：`commit 'T784168121'`;
* 如果事务在 `GTMCOORD` 上未提交，则需要在本节点回滚该事务：`rollback prepared 'T784168121'`;

上述操作需要在事务对应的 `database` 上执行，通过 `pg_prepared_xacts` 的 `database` 列值来决定。

可以用如下语句生成批量操作语句：
```sql
select 'rollback prepared '''||gid||''';' 
from pg_prepared_xacts 
where  to_char(prepared,'yyyy-mm-dd hh24:mi') ='2020-01-01 14:30'
and database = 'db1';
```


**原因说明**

无

***

###  INSERT has more target columns than expressions

**解决方式** 

目标列与表结构的列不匹配。

**原因说明**

查询语句中的目标列与表结构的列不匹配，或多或少，请仔细检查。

***

###  ERROR:  No Datanode defined in cluster

**解决方式** 

登录coordinator执行select * from pgxc_node,检查是否存在node_type=D 的节点信息。
执行select pgxc_pool_reload() 重新加载pgxc_node信息之后，重新执行上述的查询。
若仍然没有node_type=D 的节点信息，则需要重新init集群。
或若登录adbmgr执行monitor all,显示所有节点均为running状态，也可以手工初始化pgxc_node表的信息，但比较麻烦。

重新初始化集群的步骤：
登录adbmgr操作

```
stop all mode fast;
clean all;
init all;
```

手工添加pgxc_node表的初始化信息的步骤：
登录每个coordinator操作

```
--创建一个coordinator的节点信息
create node ${node_name} with (type=coordinator, host='${node_ip}', port=${node_port}, primary=false);

--创建第一个datanode master的节点信息(datanode slave不需要初始化)
create node ${node_name} with (type=datanode, host='${node_ip}', port=${node_port}, primary=true);
--创建其他datanode master的节点信息(datanode slave不需要初始化)
create node ${node_name} with (type=datanode, host='${node_ip}', port=${node_port}, primary=false);

**注：该方式比较原始，不建议这样操作。**
```

**原因说明**

init all初始化集群时，agtm没有正常初始化，导致各个节点在初始化pgxc_node时，向agtm获取事务号失败，导致pgxc_node该表初始化异常。

***

###  ERROR:  Cannot create index whose evaluation cannot be enforced to remote nodes

**解决方式** 

目前非分片键不允许创建主键或唯一索引。
若一定要创建主键，带上分片键即可。
以下给出一个示例说明：

```
postgres=# create table sy01(id int,name text) distribute by hash(name);
CREATE TABLE
postgres=# ALTER TABLE sy01 add constraint pk_sy01_1 primary key (id);
ERROR:  Cannot create index whose evaluation cannot be enforced to remote nodes
postgres=# ALTER TABLE sy01 add constraint pk_sy01_1 primary key (id,name);
ALTER TABLE
postgres=# \d+ sy01
                         Table "public.sy01"
 Column |  Type   | Modifiers | Storage  | Stats target | Description 
--------+---------+-----------+----------+--------------+-------------
 id     | integer | not null  | plain    |              | 
 name   | text    | not null  | extended |              | 
Indexes:
    "pk_sy01_1" PRIMARY KEY, btree (id, name)
Distribute By: HASH(name)
Location Nodes: ALL DATANODES
```

**原因说明**

无

### cannot create foreign key whose evaluation cannot be enforced to Remote nodes

**解决方式**     

目前不允许在非分片键上创建外键,处理方式：
- 修改子表外键字段为分片键后再创建外键。
- 如果父表数据量很小的话，可以修改父表的为复制表。

复现SQL：

```
postgres=# create table t_parent (id int primary key,name varchar(30));
create table t_child (id int,name varchar(30)) distribute by hash(name);

CREATE TABLE
postgres=# create table t_child (id int,name varchar(30)) distribute by hash(name);
CREATE TABLE
postgres=# 
postgres=# alter table t_child
postgres-#     add constraint fkey_t_child
postgres-#     foreign key (id) 
postgres-#     references t_parent (id);
ERROR:  Cannot create foreign key whose evaluation cannot be enforced to remote nodes
postgres=#
postgres=# alter table t_child distribute by hash (id);
ALTER TABLE
postgres=# alter table t_child                         
    add constraint fkey_t_child
    foreign key (id) 
    references t_parent (id);
ALTER TABLE

postgres=# drop table t_child;
DROP TABLE
postgres=# create table t_child (id int,name varchar(30)) distribute by hash(name);
CREATE TABLE
postgres=# alter table t_parent distribute by replication;
ALTER TABLE
postgres=# alter table t_child                            
postgres-#     add constraint fkey_t_child
postgres-#     foreign key (id) 
postgres-#     references t_parent (id);
ALTER TABLE
postgres=# 
```

###  fe_sendauth: no password supplied

可能的报错信息：

```
WARNING:  on coordinator   execute "set FORCE_PARALLEL_MODE = off; 				SELECT PG_PAUSE_CLUSTER();" fail ERROR:  error message from poolmgr:reconnect three thimes , fe_sendauth: no password supplied

```

处理方式：
检查下集群中coord的hba信息，是否存在：对于集群内部主机IP有md5的认证方式。

在adbmgr中执行 :`show hba nodename` 来查看节点的hba信息。

###  FATAL: invalid value for parameter "TimeZone": "Asia/Shanghai"

可能的报错信息：

```
FATAL: invalid value for parameter "TimeZone": "Asia/Shanghai"
FATAL: invalid value for parameter "TimeZone": "asia/shanghai"
FATAL: invalid value for parameter "TimeZone": "utc"
```

处理方式：
1. 检查JDBC的JAVA_OPTS，是否配置了user.timezone参数，若配置了该参数，需严格匹配数据库内默认支持的时区名的大小写。

数据库内支持的时区，使用下列sql查询，注意时区名的大小写。

select * from pg_catalog.pg_timezone_names;

若JDBC中没有配置该参数，则按步骤2的说明检查。

2. 检查AntDB二进制文件目录下的share,并确认timezone下的时区是否完整。若缺失或不完整，需要重新从一个完整的节点deploy所需的文件。
```
ll $ADBHOME/share/postgresql/timezone
total 232
drwxr-xr-x 2 antdb antdb 4096 Apr 16 15:59 Africa
drwxr-xr-x 6 antdb antdb 4096 Apr 16 15:59 America
drwxr-xr-x 2 antdb antdb 4096 Apr 16 15:59 Antarctica
drwxr-xr-x 2 antdb antdb   25 Apr 16 15:59 Arctic
drwxr-xr-x 2 antdb antdb 4096 Apr 16 15:59 Asia
......
drwxr-xr-x 2 antdb antdb 4096 Apr 16 15:59 US
-rwxr-xr-x 1 antdb antdb  114 Apr 16 15:48 UTC
-rwxr-xr-x 1 antdb antdb 1905 Apr 16 15:48 WET
-rwxr-xr-x 1 antdb antdb 1535 Apr 16 15:48 W-SU
-rwxr-xr-x 1 antdb antdb  114 Apr 16 15:48 Zulu
```

***

## 节点down后恢复

###  coordinator 节点宕机

当coordinator节点所在主机宕机后又不能及时恢复，会影响集群的DDL语句无法执行，DML语句不受影响，此时需要操作如下步骤：

通过adbmgr移除不可用coordinator节点：

```
remove coordinator coord2; # name替换成宕机的节点名称
drop coordinator coord2;
```

此时DDL语句可以正常执行。

在主机恢复后，通过如下操作重新添加该coordinator节点：

```
add coordinator coord2 (host=adb02,port=5432,path='/data/adb/coord');
clean coordinator coord2;
append coordinator coord1 to  coord2;  # coord1为当前集群中的正常coordinator节点。
append activate coordinator coord2;
```

###   datanode节点宕机后恢复

datanode节点所在主机宕机后，repmgrd后台进程会自动切换到备节点。

在主机恢复后，需要将down掉的节点重新添加到集群。

如果down掉的是master节点，则只能以slave的身份重回集群。

添加node信息：

```
add datanode slave db1 (host=adb01,port=15011,path='/data/adb/db1');
rewind datanode slave db1;
```

如果down掉的是slave节点，则直接以原来的身份进行启动即可。

```
start datanode slave db1;
```

###   gtm节点宕机

gtm节点所在主机宕机后，后台进程会自动切换到备节点。

在主机恢复后，需要将down掉的节点重新以slave的身份添加到集群。

```
add gtm slave gtm_2 for gtm_1 (host=adb03,port=7329,path='/data/adb/gtm');
clean gtm slave gtm_2;
append gtm slave gtm_2;
```

###  adbmgr节点宕机

adbmgr slave节点所在主机宕机后，不影响master的使用，待slave节点恢复后，启动即可：`mgr_start`。

adbmgr master节点所在主机宕机,keepalived会自动将slave节点提升为master，并将vip接管到slave主机上。

在adbmgr master节点恢复后，重新连接当前主节点做一个备份，执行：

```
mv /data/adb/mgr /data/adb/mgr_bak
pg_basebackup -h 192.168.1.20 -p 6433 -U adb -D /data/adb/mgr -Xs -Fp -R
chmod 700 /data/adb/mgr
mgr_ctl start -D /data/adb/mgr
# IP、port、dir均替换为实际值
```

重新启动`keepalived`：

修改`keepalived.conf`  (/etc/keepalived/keepalived.conf)

当前主节点的priority 修改为`100`，

当前备节点的priority 修改为`98`.

按照先主后备的顺序重启keepalived：

`service keepalived restart`

观察系统日志。

 

## 数据迁移

***

###  ERROR:  COPY escape available only in CSV mode

**解决方式** 

将下述copy命令中的ESCAPE 'OFF'配置项去掉即可。

```
\COPY sa.rep_check_data_report_001 from '/etldata/data_rep/sql/REPORT_00118.imp' with delimiter '' NULL AS '' ESCAPE 'OFF';
```

**原因说明**

ESCAPE选项只在csv模式生效，而该文件/etldata/data_rep/sql/REPORT_00118.imp并非csv格式。删掉ESCAPE选项即可。

***

###  FATAL: Can't open FUNCTION_/data/ora2pg/ddl/dmp_others.sql: No such file or directory

**解决方式** 

ora2pg的-o选项，建议以相对路径配置即可
下面给出一个示例说明：

```
cd /data/ora2pg/exp
ora2pg -c /data/ora2pg/conf/xxx.conf -o cz.sql
```

**原因说明**

无

***

###  使用ora2pg导出分区表时，仍以继承表的方式实现，而非最新的内置分区表方式实现。

**解决方式** 

配置文件添加下述2个新增的配置项。
其中PG_VERSION支持10/11，按实际情况配置即可。

```
PG_SUPPORTS_PARTITION 1
PG_VERSION 11
```

**原因说明**

工具调整，新增了几个配置项。

### ORA-24345: A Truncation or null fetch error occurred (DBD SUCCESS_WITH_INFO

通过oci方式导数据，会用到一个参数 `LONGREADLEN`，这个值默认是1MB，一行记录会分配1MB，N行记录就分配 N*1 MB。所以在通过ora2pg 导出lob字段的时候，可能会碰到这个报错，原因是导出的表中包含lob字段，且单字段大小超过了1MB，因此报错。

通过如下SQL在Oracle侧查出lob字段的大小：

```
select owner,TABLE_NAME,SEGMENT_NAME from dba_lobs where table_name='AD_STAGE_LOG_DTL' and owner='ADCI';
select bytes,owner,SEGMENT_NAME,bytes/1024/1024 from dba_segments where segment_name='SYS_LOB0000200510C00009$$' and owner='ADCI';
SELECT max(DBMS_LOB.GETLENGTH(FAIL_LOG))/1024/1024 as Size_MB FROM AD_STAGE_LOG_DTL;
SELECT DBMS_LOB.GETLENGTH(FAIL_LOG)/1024/1024 as Size_MB FROM AD_STAGE_LOG_DTL where FAIL_LOG is not null order by 1;
```

根据实际情况调整 ora2pg 配置文件中的参数 `LONGREADLEN`，通常来说，与lob字段的max length一致，但是也要考虑主机内存的情况。

***

## 数据备份

***

###  WAL archive: FAILED (please make sure WAL shipping is setup)

执行barman check命令时，返回上述报错信息

```
barman -c /aifs01/users/antdb01/barman/conf/datanode0.conf check datanode0
```

下面给出一个完整的配置文件示例：

```
more datanode0.conf 

[barman]
barman_user = antdb01
#configuration_files_directory = /aifs01/users/antdb01/barman/conf/
barman_home = /aifs01/users/antdb01/barman/data/
log_file = /aifs01/users/antdb01/barman/log/barman.log
compression = gzip
parallel_jobs =3
minimum_redundancy = 0
retention_policy = RECOVERY WINDOW OF 1 WEEKS
reuse_backup = off

[datanode0]
description = "datanode master datanode0"
ssh_command = ssh antdb01@10.1.242.25 -p 22022 -q
conninfo = host=10.1.242.25 port=14332 user=antdb01 dbname=tstadb
backup_method = rsync
reuse_backup = link
backup_options = exclusive_backup
parallel_jobs = 3
archiver = on
archiver_batch_size = 50
```

**解决方式** 

1. 确认datanode0的archive_mode已经设置为打开 on

```
登录adbmgr或datanode节点
show datanode0 archive_mode;
           type            | status |      message      
---------------------------+--------+-------------------
 datanode master datanode0 | t      | archive_mode = on
```

2. 确认datanode0的archive_command设置是否正确？手工执行不报ssh连接错误。

```
很多现场会修改ssh的默认端口，比如改成22022。则建议按下述步骤调整归档命令

set datanode master datanode0 (archive_command = 'rsync --address=10.1.242.27 --port=22022 -a %p antdb01@10.1.242.27:/aifs01/users/antdb01/barman/data/datanode0/incoming/%f');

如果上述的port命令不生效，还是连接的默认22端口，手工执行时，还是报连接拒绝，则使用 下面的命令设置归档
set datanode master datanode0 (archive_command = 'rsync -e "ssh -p 22022" --address=10.1.242.27 --port=22022 -a %p antdb01@10.1.242.27:/aifs01/users/antdb01/barman/data/datanode0/incoming/%f');
(各现场ssh版本不一样，可识别的配置项不同)

```

3. 手工执行一次wal日志切换操作
```
barman -c /data/antdb/barman/etc/barman.conf switch-xlog --force --archive antdb117
```

**原因说明**

要么没有打开归档模式，要么归档命令设置或执行失败。
请按上述步骤依次排查。

***

###  minimum redundancy requirements: FAILED (have 0 backups, expected at least 1)

执行barman check命令时，返回上述报错信息

```
barman -c /aifs01/users/antdb01/barman/conf/datanode0.conf check datanode0
```

解决方式** 

datanode0.conf的minimum_redundancy修改为0

```
minimum_redundancy = 0
```

**原因说明**

无

***

###  ssh output clean: FAILED (the configured ssh_command must not add anything to the remote command output)

执行barman check命令时，返回上述报错信息

```
barman -c /aifs01/users/antdb01/barman/conf/datanode0.conf check datanode0
```

解决方式** 

1. datanode0.conf 的 ssh_command 命令，在最后添加 -q 选项，不产生任何输出信息.

```
ssh_command = ssh antdb01@10.1.242.25 -p 22022 -q
```

详细的原因说明，请参考：
The test that Barman does is to execute 'true' using the ssh_command and checking that the output is empty. 

In your case, please check that the following command doesn't produce any output.

链接：https://groups.google.com/forum/#!topic/pgbarman/1xjUU4mnrfI

2. 确保archive_command和barman配置文件中几个变量值的对应关系

```
----------archive_command命令示例：
archive_command = 'rsync --address=10.1.242.27 --port=22022 -a %p antdb01@10.1.242.27:/aifs01/users/antdb01/barman/data/datanode0/incoming/%f'

---------datanode0.conf配置示例：

[barman]
barman_home = /aifs01/users/antdb01/barman/data/

[datanode0]

--------两者对应关系：
archive_command命令中的
/aifs01/users/antdb01/barman/data/datanode0
必须等于
datanode0.conf配置文件中的 barman_home的配置值 + [datanode0]的配置值
/aifs01/users/antdb01/barman/data/datanode0
即：
barman_home的配置值 + [datanode0]的配置值 + 'incoming/%f'固定字符串
```

**原因说明**

centos7.2以后，某些ssh场景下需要静默返回输出，即ssh命令添加了 -q 静默选项，否则就报标题所示的错误。

***

###  ERROR:  invalid byte sequence for encoding "UTF8":
场景：使用copy命令导入数据  例如
```
\copy t1 from 't1.csv' with csv
``` 
**原因说明**

导入的文件中含非UTF8字符集的内容，通常为GBK字符集的中文

**解决方式**

1. 修改导入文件编码为UTF8  
2. 指定字符集 \copy t1 from 't1.csv' with csv encoding 'GBK'
3. libpq中可通过PQsetClientEncoding(conn,"GBK") 方法指定字符集
