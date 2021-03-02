# 快速安装AntDB集群

AntDB（为了方便后续都简称为ADB）集群，有单独的一个管理模块（ADB manger）来管理，监控和维护。详细信息可以参考《AntDB使用手册》。下面就简单介绍下如何通过ADB manager快速部署AntDB 集群。

## 安装Adbmgr

###  准备环境

#### 创建用户

在root用户下执行：`useradd antdb` 进行`antdb`用户的创建。

执行：`passwd antdb` 修改`antdb`用户密码。

#### 配置用户limit参数

编辑`/etc/security/limits.conf ` 文件，配置`antdb`用户参数：

```
antdb soft nproc 65536
antdb hard nproc 65536
antdb soft nofile 278528
antdb hard nofile 278528
antdb soft stack unlimited
antdb soft core unlimited
antdb hard core unlimited
antdb soft memlock 250000000
antdb hard memlock 250000000
```

保存文件后，执行`su - antdb`切换到`antdb`用户，执行`ulimit -a` 检查是否生效。

#### 配置用户sudo权限

> 可选步骤。

在安全允许的条件下，建议给`antdb`用户加上`sudo`权限。

root用户执行`visudo` 进行编辑界面，找到 `Allow root to run any commands anywhere`所在行，在行下面添加：

```
antdb        ALL=(ALL)       ALL
```

保存文件退出。`su - antdb` 切换到`antdb`用户，执行`sudo id`，预期会提示输入用户密码，输出为：

```
uid=0(root) gid=0(root) groups=0(root)
```

表示`sudo`权限添加成功。

#### 安装依赖

> 单机版可以不用安装 `libssh2`。

在cento或者redhat操作系统下，执行如下命令安装依赖：

```
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
yum install -y libssh2-devel
```

Ubuntu操作系统执行如下命令安装依赖：

```
apt-get install flex 
apt-get install bison
apt-get install libreadline6-dev 
apt-get install libssl-dev
apt-get install libpam-dev
apt-get install libxml2
apt-get install libxml2-dev
apt-get install libxslt-dev
apt-get install libldap-dev
apt-get install libperl-dev
apt-get install libpython-dev
apt-get install libssh2-1-dev
```

suse操作系统执行如下命令安装依赖：

```
zypper install -y flex 
zypper install -y bison
zypper install -y readline-devel
zypper install -y zlib-devel
zypper install -y libopenssl-devel
zypper install -y pam-devel
zypper install -y libxml2-devel
zypper install -y libxslt-devel
zypper install -y openldap-devel
zypper install -y python-devel
zypper install -y gcc-c++ 
zypper install -y libssh2-devel
```

> 其他操作系统请参考操作系统使用手册更换安装命令即可，依赖包名称不变

部分依赖源中没有提供 `libssh2` 的包，可以通过源码编译安装：
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

> libssh2 可以仅在adbmgr所在主机上安装。

#### 调整操作系统参数

参见附录：操作系统参数部分。

###  源码安装Adbmgr

---
> 切换到`antdb`用户下。

Adbmgr 与AntDB 集群的源码绑定在一起，所以编译Adbmgr，就是编译AntDB 集群的源码。

下面是编译安装步骤：  
- step 1: `mkdir build `
- step 2: `cd build `
- step 3: `../AntDB/configure --prefix=/opt/app/antdb --with-perl --with-python --with-pam --with-ldap --with-libxml --with-libxslt --enable-thread-safety --enable-debug --enable-cassert CFLAGS="-DWAL_DEBUG -O2 -ggdb3"  `
- step 4: `make install-world-contrib-recurse  `

> 编译Adbmgr 过程中会提示各种库没有安装，如何安装这些库，请参考操作系统的库软件安装说明。
>
> step3 中 `--prefix` 可以修改为实际目录，`antdb`用户对该目录需要有读写权限。
>
> 源码安装和RPM安装任选其一。

### RPM安装 Adbmgr

---
rpm需要通过**root** 用户或者具有**sudo**权限的用户安装。

通过交付人员提供的rpm包来安装：

```
rpm -ivh antdb-xxx.rpm
```

> 在执行rpm安装之前，需要找AntDB交付人员咨询rpm包的安装路径。
>
> 默认安装路径为：/opt/app/antdb 

如果想安装到其他路径，可以通过如下方式：

```
rpm -ivh antdb-xxx.rpm --relocate=/opt/app/antdb=$ADBHOME
```

> $ADBHOME 为自定义目录，名称最好做到见名知意，比如：`/home/antdb/app/antdb`

RPM包安装完成后，`ADB_HOME`这个变量的值要么是`/opt/app/antdb `,要么是您自定义的目录。接下来需要修改目录权限：

```
chown -R antdb:antdb $ADBHOME
chmod -R 755 $ADBHOME
```

> 若使用具有`sudo`权限的`antdb`用户进行安装，则以上命令：`rpm`、`chown`、`chmod` 前面均需要加上`sudo`。
>
> 以上安装操作只需在集群中的一台主机上执行即可，选定的这台主机建议是adbmgr所在的主机。

### 初始化Adbmgr

---
编译或安装Adbmgr 之后，会在指定目录(即`$ADBHOME`目录)的bin目录下产生`initmgr`，和`mgr_ctl`可执行文件。要想初始化Adbmgr 还需要配置PATH变量才行。
向当前用户下的隐藏文件 `.bashrc`中,执行`vim ~/.bashrc`打开文件，追加如下内容：

```shell
export ADBHOME=/opt/app/antdb 
export PATH=$ADBHOME/bin:$PATH
export LD_LIBRARY_PATH=$ADBHOME/lib:$LD_LIBRARY_PATH
export PGDATABASE=postgres

export mgrdata=/data/antdb/mgr1
alias adbmgr='psql -p 6432 -d postgres '
alias mgr_stop='mgr_ctl stop -D $mgrdata -m fast'
alias mgr_start='mgr_ctl start -D $mgrdata'
```
> ADBHOME需要根据AntDB的编译产生的二进制可执行文件的存放路径设置。
>
> mgrdata 同样需要根据各自环境的实际路径进行修改。

然后执行`source ~/.bashrc` 使其生效即可。

执行下面命令开始初始化Adbmgr：

```
initmgr -D $mgrdata
```

其中`$mgrdata`是用户自己指定的存放Adbmgr 的安装目录。

初始化后，在指定的目录下生成如下文件：
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
### 修改Adbmgr配置参数

修改postgresql.conf

```
cat  >> ${mgrdata}/postgresql.conf << EOF
port = 6432
listen_addresses = '*'
log_directory = 'pg_log'
log_destination ='csvlog'
logging_collector = on
log_min_messages = error
max_wal_senders = 3
hot_standby = on
wal_level = replica
EOF
```

修改pg_hba.conf

```
cat  >> ${mgrdata}/pg_hba.conf << EOF
host    replication     all        10.0.0.0/8                 trust
host    all             all          10.0.0.0/8               trust
EOF
```

> hba中的IP需要根据实际情况进行修改。
>

###  启动 Adbmgr

---
Adbmgr初始化成功后，就可以启动它了。有如下两种启动方式，可以任选一种执行。

- **mgr_ctl start -D /data/antdb/mgr1**
- **adbmgrd -D /data/antdb/mgr1 &**

> /data/antdb/mgr1要与初始化路径保持一致，均为变量`mgrdata` 的值。
>

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
### 待写-配置备机Adbmgr



###  停止Adbmgr

---
命令格式：
- **mgr_ctl stop -D /data/antdb/mgr1**
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

##  搭建AntDB 集群

通过Adbmgr可以快速搭建集群，因此需要先按照第二章的步骤安装完Adbmgr。接下来通过psql客户端来了解一下Adbmgr是如何管理AntDB 集群的。
通过如下命令可以登录到Adbmgr上：

```
psql -d postgres -p 6432 
```

### 添加主机(host)

---
Adbmgr通过三张表格管理集群，host、node和param表。

- host表用来存储搭建AntDB 集群所需要的所有主机信息。

- node表用来存储搭建AntDB 集群所有的节点信息。
- param表用来存储对AntDB 集群中节点参数设置的所有信息。

首先需要在host表中添加主机信息，后面gtmcoord、datanode、coordinator会部署到这些主机上:

添加命令|	add host 主机名(address, agentport,user,adbhome);
--|--
**查看命令**|	list host;

部分参数可以不写，有默认值， 例如port默认22，user默认值是当前用户;

**举例：**

```sql
add host adb01(port=22,protocol='ssh',adbhome='/opt/app/antdb',address="10.1.226.201",agentport=8432,user='antdb');
add host adb02(port=22,protocol='ssh',adbhome='/opt/app/antdb',address="10.1.226.202",agentport=8432,user='antdb');
add host adb03(port=22,protocol='ssh',adbhome='/opt/app/antdb',address="10.1.226.203",agentport=8432,user='antdb');
```

> 此处`adbhome`的值与`.bashrc`中`ADBHOME`的值应该一致。

###  deploy二进制程序

---
deploy命令会将AntDB的二进制执行文件打包发送到host表中所有主机上。对于第一次部署集群，或者集群的安装包有更新，为了集群安装的稳定性，则应首先手动清空集群下所有主机的执行文件。
在集群内各主机之间如果没有设置互信的情况下，执行deploy all需要输入用户密码（当前用户的登录密码），如果设置主机间互信，则可以省去密码的繁琐设置。
**命令：**

一次部署所有主机| deploy all password ' 123456'; 
---|---
**部署指定的主机**	|**deploy adb01,adb02 password ' 123456';**

### 启动agent

---
有两种方式：一次启动全部agent和单独启动一台主机agent（多个主机需要多次执行）。

> password是host表中主机user对应的linux系统密码，用于与主机通信，而非AntDB数据库的用户密码。

当密码是以数字开头时，需要加上单引号或者双引号，例如password ‘12345z’是正确的，password 12345z则会报错；如果密码不是以数字开头，则加不加引号都行。

一次启动全部agent| start agent all  password ' 123456'; 
---|---
**启动指定的agent**	|**start agent adb01,adb02 password ' 123456';**

当密码不对，启动agent失败时，报错如下：
```shell
postgres=# start agent adb01 password '123456abc';    
  hostname  | status |                description                
------------+--------+-------------------------------------------
 adb01      | f      | Authentication failed (username/password)
(1 row)
```

###  配置集群节点

---
Node表中添加gtmcoord、coordinator、datanode master、datanode slave等节点信息。

> host名称必须来自host表，端口号不要冲突，path指定的文件夹下必须为空，否则初始化将失败并报错。这种设置，是防止用户操作时，忘记当前节点下还有有用的数据信息。

**添加命令：**

add节点 | command
---|---
添加coordinator信息|add coordinator master 名字(path = 'xxx', host='localhost1', port=xxx);
添加datanode master信息|add datanode master 名字(path = 'xxx', host='localhost1', port=xxx);
添加datanode slave信息，从节点与master不同名，所以指定的master必须存在，同异步关系通过SYNC_STATE参数设置|add datanode slave名字 for master_name (host='localhost2', port=xxx, path='xxx', SYNC_STATE='sync');
添加gtmcoord信息，从节点必须与主节点不同名，所以指定的master必须存在，同异步关系通过SYNC_STATE参数设置|add gtmcoord master名字(host='localhost3',port=xxx, path='xxx');add gtmcoord slave名字 for maste_name(host='localhost2',port=xxx, path='xxx')

添加完成后，使用命令`list node`查看刚刚添加的节点信息

**举例：（gtm/datanode 均为一主一从）**

```sql
add host adb01(port=22,protocol='ssh',adbhome='/opt/app/antdb',address="10.1.226.201",agentport=8432,user='antdb');
add host adb02(port=22,protocol='ssh',adbhome='/opt/app/antdb',address="10.1.226.202",agentport=8432,user='antdb');
add host adb03(port=22,protocol='ssh',adbhome='/opt/app/antdb',address="10.1.226.203",agentport=8432,user='antdb');
add coordinator master cn1(host='adb01', port=5432,path = '/home/antdb/data/cn1');
add coordinator master cn2(host='adb02', port=5432,path = '/home/antdb/data/cn2');
add datanode master dn1_1(host='adb01', port=14332,path = '/home/antdb/data/dn1_1');
add datanode slave dn1_2 for dn1_1 (host='db02',port=14332,path='/home/antdb/data/dn1_2');
add datanode master dn2_1(host='adb02', port=24332,path = '/home/antdb/data/dn2_1');
add datanode slave dn2_2 for dn2_1(host='adb01',port=24332,path='/home/antdb/data/dn2_2');
add gtmcoord master gc_1(host='adb03',port=6655, path='/home/antdb/data/gc_1');
add gtmcoord slave gc_2 for gc_1(host='adb02',port=6655,path='/home/antdb/data/gc_2');
```

### 配置节点参数

---
**set param:**

同时设置所有同类型节点：
>set datanode|coordinator|gtmcoord all(key1=value1, key2=value2...); 

设置某一个节点的参数:

>set{datanode|coordinator|gtmcoord} {master|slave|extra} {nodename|all} (key1=value1, key2=value2...);

注意：相同的参数，slave的参数必须大于等于master，否则启动失败，查看log如下：
> 2017-10-17 10:50:55.730 CST 22023 0FATAL:  hot standby is not possible because max_prepared_transactions = 100 is a lower setting than on the master server (its value was 150)

**reset param:**

reset参数：
>reset {datanode|coordinator|gtmcoord} {master|slave|extra} {nodename|all} (key1,key2...); （key,...） ；也可以支持 （key=value,key2,...），不过此时value值没有作用。
>若parm表中存在参数设置，则删除

更多参数的设置，请参考附录：数据库参数设置部分。

###  init all启动集群

---
集群的节点都已经配置完成，此时就可以使用命令`init all`启动集群了。如下图，可以看到`init all`内部的操作步骤。
```shell
postgres=# init all ;
    operation type     | nodename | status | description 
-----------------------+----------+--------+-------------
 init gtmcoord master  | gc_1      | t      | success
 start gtmcoord master | gc_1      | t      | success
 init coordinator      | cn1        | t      | success
 init coordinator      | cn2   			| t      | success
 start coordinator     | cn1   			| t      | success
 start coordinator     | cn2  			| t      | success
 init datanode master  | dn1_1      | t      | success
 init datanode master  | dn2_1      | t      | success
 start datanode master | dn1_1      | t      | success
 start datanode master | dn2_1      | t      | success
 init gtmcoord slave   | gc_2      | t      | success
 start gtmcoord slave  | gc_2      | t      | success
 init datanode slave   | dn1_2      | t      | success
 init datanode slave   | dn1_2      | t      | success
 start datanode slave  | dn2_2      | t      | success
 start datanode slave  | dn2_2      | t      | success
 config coordinator    | cn1        | t      | success
 config coordinator    | cn2        | t      | success
(18 rows)
```
通过`monitor all `查看集群各个节点的运行状态：
```shell
postgres=# monitor all ;
 nodename |    nodetype           | status | description |     host     | port  
----------+-----------------+--------+-------------+--------------+------------
 cn1      | coordinator  master   | t      | running     | 10.1.226.201 |  5432
 cn2      | coordinator  master   | t      | running     | 10.1.226.202 |  5432
 dn1_1    | datanode master       | t      | running     | 10.1.226.201 | 14332
 dn1_2    | datanode slave        | t      | running     | 10.1.226.202 | 14332
 dn2_1    | datanode master       | t      | running     | 10.1.226.202 | 24332
 dn2_2    | datanode slave        | t      | running     | 10.1.226.201 | 24332
 gc_1     | gtmcoord master       | t      | running     | 10.1.226.203 |  6655
 gc_2     | gtmcoord slave        | t      | running     | 10.1.226.202 |  6655
(8 rows)
```
**至此，AntDB集群初始化完成！**



## 附录

### 操作系统参数配置

####  关闭防火墙

```
# centos 6
servcie iptables stop 
chkconfig iptables off

# centos 7
systemctl stop firewalld.service
systemctl disable firewalld.service

# suse12
systemctl stop SuSEfirewall2.service
systemctl disable SuSEfirewall2.service
```

#### 关闭numa和THP

```
# redhat/centos 6
# vim /etc/grub.conf
default=0
timeout=5
splashimage=(hd0,0)/grub/splash.xpm.gz
hiddenmenu
title Red Hat Enterprise Linux 6 (2.6.32-504.el6.x86_64)
        root (hd0,0)
        kernel /vmlinuz-2.6.32-504.el6.x86_64 ro root=/dev/mapper/vg_os-lv_os rd_NO_LUKS LANG=en_US.UTF-8 rd_NO_MD SYSFONT=latarcyrheb-sun16 crashkernel=auto rd_LVM_LV=vg_os/lv_os  KEYBOARDTYPE=pc KEYTABLE=us rd_NO_DM rhgb quiet numa=off transparent_hugepage=never
# 关闭服务
service tuned stop
chkconfig tuned off
service ktune stop
chkconfig ktune off


# redhat/centos 7
grubby --update-kernel=ALL --args="numa=off transparent_hugepage=never"  # 该命令修改的是这个文件：/etc/grub2.cfg
grub2-mkconfig 

# 关闭服务
systemctl stop tuned
systemctl disable tuned

这种方式修改后，重启主机生效。

# 重启后，验证grub的cmdline：
cat /proc/cmdline


#检查 numa
numactl --hardware
预期结果为：
available: 1 nodes (0)

#检查 transparent_hugepage
cat /sys/kernel/mm/transparent_hugepage/enabled
预期结果为：
always madvise [never]
```

#### sysctl.conf 配置

```shell

cat >>  /etc/sysctl.conf << EOF
# add for antdb
kernel.shmmax=137438953472 137438953472
kernel.shmall=53689091
kernel.shmmni=4096
kernel.msgmnb=4203520
kernel.msgmax=65536
kernel.msgmni=32768
kernel.sem=501000 641280000 501000 12800

fs.aio-max-nr=6553600
fs.file-max=26289810
net.core.rmem_default=8388608
net.core.rmem_max=16777216
net.core.wmem_default=8388608
net.core.wmem_max=16777216
net.core.netdev_max_backlog=262144
net.core.somaxconn= 65535
net.ipv4.tcp_rmem=8192 87380 16777216
net.ipv4.tcp_wmem=8192 65536 16777216
net.ipv4.tcp_max_syn_backlog=262144
net.ipv4.tcp_keepalive_time=180
net.ipv4.tcp_keepalive_intvl=10
net.ipv4.tcp_keepalive_probes=3
net.ipv4.tcp_fin_timeout=1
net.ipv4.tcp_synack_retries=1
net.ipv4.tcp_syn_retries=1
net.ipv4.tcp_syncookies=1
net.ipv4.tcp_timestamps=1
net.ipv4.tcp_tw_recycle=1
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_max_tw_buckets=256000
net.ipv4.tcp_retries1=2
net.ipv4.tcp_retries2=3
vm.dirty_background_ratio=5
vm.dirty_expire_centisecs=6000
vm.dirty_writeback_centisecs=500
vm.dirty_ratio=20
vm.overcommit_memory=0
vm.overcommit_ratio= 120
vm.vfs_cache_pressure = 100
vm.swappiness=10
vm.drop_caches = 2
vm.min_free_kbytes = 2048000
vm.zone_reclaim_mode=0
kernel.core_uses_pid=1
kernel.core_pattern= core-%e-%p-%s-%t
fs.suid_dumpable=1
kernel.sysrq=0
EOF
```

> `kernel.core_pattern`的路径需要根据实际环境信息进行修改。

执行`sysctl -p`让上述参数生效

### 数据库参数配置

数据库参数参考值：

```
-- mgrcoord:
export gcdata=""
cat  >> ${gcdata}/postgresql.conf << EOF
port = 18610
listen_addresses = '*'
log_directory = 'pg_log'
log_destination ='csvlog'
logging_collector = on
log_min_messages = error
max_wal_senders = 3
hot_standby = on
wal_level = replica
EOF

cat  >> ${gcdata}/pg_hba.conf << EOF
host    replication     shboss        10.0.0.0/8                 trust
host    all             all          10.0.0.0/8               trust
EOF

--coord:
--Modify according to actual situation/请用户根据主机环境信息，适当调整
SET COORDINATOR ALL (shared_buffers = '1GB' );
SET COORDINATOR ALL (maintenance_work_mem = '1024MB');
SET COORDINATOR ALL (work_mem = '128MB' );
SET COORDINATOR ALL (max_connections = 1000 );
SET COORDINATOR ALL (max_prepared_transactions = 1000 );
SET COORDINATOR ALL (max_parallel_workers = 10 );
SET COORDINATOR ALL (max_parallel_workers_per_gather = 10 );
----
SET COORDINATOR ALL (log_truncate_on_rotation = on);
SET COORDINATOR ALL (log_rotation_age = '7d');
SET COORDINATOR ALL (log_rotation_size = '100MB');
SET COORDINATOR ALL (log_min_messages = error );
SET COORDINATOR ALL (log_min_duration_statement = 50 );
SET COORDINATOR ALL (log_connections = on );
SET COORDINATOR ALL (log_disconnections = on);
SET COORDINATOR ALL (log_duration = off);
SET COORDINATOR ALL (log_statement = 'ddl' );
SET COORDINATOR ALL (log_checkpoints = on );
SET COORDINATOR ALL (adb_log_query = on );
SET COORDINATOR ALL (unix_socket_permissions =0700);
SET COORDINATOR ALL (listen_addresses = '*' );
SET COORDINATOR ALL (superuser_reserved_connections = 13);
SET COORDINATOR ALL (tcp_keepalives_idle = 180);
SET COORDINATOR ALL (tcp_keepalives_interval = 10 );
SET COORDINATOR ALL (tcp_keepalives_count = 3 );
SET COORDINATOR ALL (track_counts = on);
SET COORDINATOR ALL (track_activity_query_size = 2048 );
SET COORDINATOR ALL (max_locks_per_transaction = 128);
SET COORDINATOR ALL (constraint_exclusion = on);
SET COORDINATOR ALL (wal_level='replica');
SET COORDINATOR ALL (max_wal_senders = 3);
SET COORDINATOR ALL (hot_standby = on);
SET COORDINATOR ALL (autovacuum_max_workers = 5 );
SET COORDINATOR ALL (autovacuum_naptime = '60min');
SET COORDINATOR ALL (autovacuum_vacuum_threshold = 500);
SET COORDINATOR ALL (autovacuum_analyze_threshold = 500 );
SET COORDINATOR ALL (autovacuum_vacuum_scale_factor = 0.5 );
SET COORDINATOR ALL (autovacuum_vacuum_cost_limit = -1);
SET COORDINATOR ALL (autovacuum_vacuum_cost_delay = '30ms');
SET COORDINATOR ALL (lock_timeout = '180s');
SET COORDINATOR ALL (fsync = off);
SET COORDINATOR ALL (synchronous_commit = off );
SET COORDINATOR ALL (wal_sync_method = open_datasync);
SET COORDINATOR ALL (full_page_writes = off );
SET COORDINATOR ALL (commit_delay = 10);
SET COORDINATOR ALL (commit_siblings = 10 );
--SET COORDINATOR ALL (checkpoint_segments = 256); #only for 2.x version
SET COORDINATOR ALL (checkpoint_timeout = '15min'); 
SET COORDINATOR ALL (checkpoint_completion_target=0.9 );
SET COORDINATOR ALL (max_wal_size = 10240);
SET COORDINATOR ALL (archive_mode = on);
SET COORDINATOR ALL (archive_command = '/bin/date');
--SET COORDINATOR ALL (max_stack_depth = '8MB');
SET COORDINATOR ALL (bgwriter_delay = '10ms');
SET COORDINATOR ALL (bgwriter_lru_maxpages = 1000 );
SET COORDINATOR ALL (bgwriter_lru_multiplier = 10.0 );
SET COORDINATOR ALL (pool_time_out = 300);
SET COORDINATOR ALL (enable_pushdown_art = on );

--datanode:
--Modify according to actual situation/请用户根据主机环境信息，适当调整
SET DATANODE ALL (shared_buffers = '1GB' );
SET DATANODE ALL (maintenance_work_mem = '1024MB');
SET DATANODE ALL (work_mem = '128MB' );
SET DATANODE ALL (max_connections = 3000 );
SET DATANODE ALL (max_prepared_transactions = 3000 );
SET DATANODE ALL (wal_keep_segments = 128 );
SET DATANODE ALL (effective_cache_size = '15GB' );
SET DATANODE ALL (max_parallel_workers = 10 );
SET DATANODE ALL (max_parallel_workers_per_gather = 10 );
----
SET DATANODE ALL (log_truncate_on_rotation = on);
SET DATANODE ALL (log_rotation_age = '7d' );
SET DATANODE ALL (log_rotation_size = '100MB' );
SET DATANODE ALL (log_min_messages = error);
SET DATANODE ALL (log_min_error_statement = error );
SET DATANODE ALL (log_duration = off);
SET DATANODE ALL (log_statement = 'ddl' );
SET DATANODE ALL (unix_socket_permissions = '0700' );
SET DATANODE ALL (listen_addresses = '*');
SET DATANODE ALL (superuser_reserved_connections = 13 );
SET DATANODE ALL (track_counts = on );
SET DATANODE ALL (track_activity_query_size = 2048);
SET DATANODE ALL (max_locks_per_transaction = 64);
SET DATANODE ALL (constraint_exclusion = on );
set DATANODE ALL (wal_level='replica');
SET DATANODE ALL (max_wal_senders = 5 );
set DATANODE all (wal_log_hints = on);
SET DATANODE ALL (autovacuum = on );
SET DATANODE ALL (autovacuum_max_workers = 5);
SET DATANODE ALL (autovacuum_naptime = '60min' );
SET DATANODE ALL (autovacuum_vacuum_threshold = 500 );
SET DATANODE ALL (autovacuum_analyze_threshold = 500);
SET DATANODE ALL (autovacuum_vacuum_scale_factor = 0.5);
SET DATANODE ALL (autovacuum_vacuum_cost_limit = -1 );
SET DATANODE ALL (autovacuum_vacuum_cost_delay = '30ms' );
SET DATANODE ALL (statement_timeout = 0 );
SET DATANODE ALL (lock_timeout = '180s' );
SET DATANODE ALL (fsync = off);
SET DATANODE ALL (synchronous_commit = off);
SET DATANODE ALL (wal_sync_method = open_datasync );
SET DATANODE ALL (full_page_writes = off);
SET DATANODE ALL (wal_writer_delay = '200ms');
SET DATANODE ALL (commit_delay = 10 );
SET DATANODE ALL (commit_siblings = 10);
SET DATANODE ALL (checkpoint_timeout = '15min' );
SET DATANODE ALL (checkpoint_completion_target = 0.9);
SET DATANODE ALL (max_wal_size = 10240);
SET DATANODE ALL (archive_mode = on );
SET DATANODE ALL (archive_command = '/bin/date' );
--SET DATANODE ALL (max_stack_depth = '8MB' );
SET DATANODE ALL (max_prepared_transactions = 4800);
SET DATANODE ALL (bgwriter_delay = '10ms' );
SET DATANODE ALL (bgwriter_lru_maxpages = 1000);
SET DATANODE ALL (bgwriter_lru_multiplier = 10.0);
SET DATANODE ALL (rep_max_avail_flag = on );

--gtmcoord:
SET GTMCOORD ALL (shared_buffers = '2GB' );
SET GTMCOORD ALL(max_connections = 3000);
SET GTMCOORD ALL(max_prepared_transactions = 3000);
SET GTMCOORD ALL (fsync = off);
set GTMCOORD ALL (wal_level='replica');
SET GTMCOORD ALL (max_wal_senders = 5 );
```
