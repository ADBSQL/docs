
# 使用Patroni搭建AntDB单机版本高可用集群

AntDB单机版本的高可用使用`patroni`进行管理，主要功能包括：
* 节点监控
* 节点故障自动切换
* old master 恢复后自动加入集群
* 计划性 switchover

`patroni` 文档地址：https://patroni.readthedocs.io/en/latest/README.html

## 相关软件位置：

> http://120.55.76.224/files/patroni/


## 主机环境

| 主机IP           | 安装组件                                       |
| --------------- | --------------------------------------------- |
| 192.168.242.101 | AntDB 5.0 + Patroni 1.6.3 + etcd + Python 3.8 |
| 192.168.242.102 | AntDB 5.0 + Patroni 1.6.3 + etcd + Python 3.8 |
| 192.168.242.103 | AntDB 5.0 + Patroni 1.6.3 + etcd + Python 3.8 |

主机操作系统版本为 CentOS 7.7，安装方式为 Minimal 安装

> 实际生产上`Python`可以使用系统自带，但要求是V2.7+。

## 创建用户【root】

```shell
# 创建用户并设置密码
useradd antdb
passwd antdb

# 添加 antdb 到 sudo 中
echo 'antdb  ALL=(ALL)  NOPASSWD: ALL' >> /etc/sudoers
```

## 操作系统配置【root】

```shell
cat >> /etc/security/limits.conf <<EOF

# Add for antdb by hongye
antdb soft nproc 65536
antdb hard nproc 65536
antdb soft nofile 278528
antdb hard nofile 278528
antdb soft stack unlimited
antdb soft core unlimited
antdb hard core unlimited
antdb soft memlock 250000000
antdb hard memlock 250000000
EOF

cat >>  /etc/sysctl.conf << EOF

# add for antdb by hongye
kernel.shmmax=17179869184 # 16GB
kernel.shmall=4194304     # 16GB / 4KB
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
kernel.core_pattern=/home/antdb/data/coredump/core-%e-%p-%t
kernel.sysrq=0
EOF
```

## 系统Package安装【root】

```shell
yum install -y perl-ExtUtils-Embed \
 flex \
 bison \
 readline-devel \
 zlib-devel \
 openssl-devel \
 pam-devel \
 libxml2-devel \
 libxslt-devel \
 openldap-devel \
 python-devel \
 gcc-c++ \
 libssh2-devel \
 perl-Data-Dumper \
 python-setuptools.noarch \
 gcc \
 unzip \
 dstat \
 libffi-devel   # 解决错误： ModuleNotFoundError: No module named '_ctypes'
```


## 源码AntDB安装【antdb】

```shell
# 软件安装
cd /home/antdb
unzip adb_sql.zip
mkdir /home/antdb/adb_sql/build
cd /home/antdb/adb_sql/build
../configure --prefix=/home/antdb/app/antdb_5.0 --enable-grammar-oracle --with-python --disable-cluster
make install-world-contrib-recurse


# 配置用户环境变量
cat >> /home/antdb/.bashrc <<"EOF"

# Add for antdb by hongye
export ADBHOME=/home/antdb/app/antdb_5.0
export PATH=$ADBHOME/bin:$PATH
export LD_LIBRARY_PATH=$ADBHOME/lib:$LD_LIBRARY_PATH
export PGDATABASE=postgres
export PGPORT=5432
export PGHOST=127.0.0.1
export PGDATA=/home/antdb/data/data_5.0
EOF
source /home/antdb/.bashrc


# 初始化数据库，只在第一节点运行（192.168.242.101）
initdb

# 配置基本数据库参数，只在第一节点运行（192.168.242.101）
cat >> $PGDATA/postgresql.conf <<EOF

# add for antdb by hongye
wal_level = replica
archive_mode = on
archive_command = '/bin/date'
max_wal_senders = 10
wal_keep_segments = 512
hot_standby = on
shared_buffers = 512MB
max_connections = 300
port = 5432
listen_addresses = '*'
log_directory = 'pg_log'
log_destination ='csvlog'
logging_collector = on
log_min_messages = error
EOF

# 配置访问权限控制，只在第一节点运行（192.168.242.101）
cat >> $PGDATA/pg_hba.conf <<EOF

# add for antdb by hongye
host  replication   all   192.168.242.0/24    trust
host  all           all   192.168.242.0/24    trust
EOF

# 启动数据块，只在第一节点运行（192.168.242.101）
pg_ctl start

# 搭建其他节点的备库，在第其他节点运行（192.168.242.102, 192.168.242.103）
pg_basebackup -D /home/antdb/data/data_5.0 -Fp -R -Xs -v -P -h 192.168.242.101 -p 5432 -U antdb
pg_ctl start
```


## Python 3.8【root】（可选）

> 如果担心修改Python版本会引起系统中的其他依赖受影响，则此步骤可以不做。
> 如果没有安装`python3`,则后续命令中的`python3`需要修改为：`python`。

```shell
cd /home/antdb/
tar -zxvf Python-3.8.0.tgz
cd Python-3.8.0
./configure --enable-shared    # 不要加 --enable-optimizations，否则会导致 make 编译报错
make
make install



# 防止找不到命令的报错： 
# sudo: pip3: command not found
sudo ln -s /usr/local/bin/pip3 /usr/bin/pip3
sudo ln -s /usr/local/bin/python3 /bin/python3


# 防止找不到库报错：
# python3: error while loading shared libraries: libpython3.8.so.1.0: cannot open shared object file: No such file or directory
echo "/usr/local/lib" >> /etc/ld.so.conf.d/python_3.8.conf
ldconfig -v
python3
```

## 安装 psycopg2

> psycopg2 的安装需要依赖 `pg_config`,通过RPM安装的AntDB，在升级版本的时候，需要卸载antdb的rpm包，此时可以通过变通的方式绕过，将$ADB_HOME 复制到 /usr/antdb 下面，然后将 `setup.cfg` 中的pg_config配置为`/usr/antdb/app/bin/pg_config`,这样 psycopg2 依赖的pg_config就不是AntDB RPM 所安装的路径，AntDB 在升级版本的时候，就可以安全的进行rpm 卸载。


```
sudo mkdir -p /usr/antdb/app
sudo cp -R /data/antdb/app/*  /usr/antdb/app/
sudo ls -lrt /usr/antdb/app/
```


修改 `/etc/ld.so.conf.d/antdb.conf`:
```
sudo vi /etc/ld.so.conf.d/antdb.conf
/usr/antdb/app/lib
```

生效配置：`sudo ldconfig -v`


安装
```
cd /home/antdb/
tar -zxvf psycopg2-2.8.4.tar.gz
cd psycopg2-2.8.4

vi setup.cfg
pg_config = /usr/antdb/app/bin/pg_config

sudo python3 setup.py install
# ImportError: libpq.so.5: cannot open shared object file: No such file or directory
```

修改 site-packages 权限：
```
sudo chmod -R 755 /usr/lib64/python*/site-packages
sudo chmod -R 755 /usr/lib/python*/site-packages
```


检查：
```
python -c "import psycopg2; print(psycopg2.__version__)"
sudo python -c "import psycopg2; print(psycopg2.__version__)"
```



## 安装Patroni【antdb】

```shell
cd /home/antdb
tar -zxvf patroni_1.6.3.tar.gz
sudo pip3 install --no-index --find-links=file:/home/antdb/patroni_1.6.3 patroni
sudo pip3 install --no-index --find-links=file:/home/antdb/patroni_1.6.3 python-etcd

# 检查 Patroni
which patroni
patroni -h
```


##  安装etcd【antdb】

```
cd /home/antdb/
tar -zxvf etcd-v3.3.18-linux-amd64.tar.gz 
cd /home/antdb/etcd-v3.3.18-linux-amd64
sudo cp etcd /usr/bin
sudo cp etcdctl /usr/bin

which etcd
which etcdctl
```


## Etcd 的配置与启动【antdb】

### 配置etcd参数【antdb】

```shell
sudo mkdir /etc/etcd

# 以下参数不同节点配置有区别（注意修改name和initial-cluster，以及其他配置项中的本节点IP）
sudo cat > /etc/etcd/conf.yaml <<EOF
name: etcd-3
data-dir: /var/lib/etcd/data
listen-client-urls: http://192.168.242.101:2379,http://127.0.0.1:2379
advertise-client-urls: http://192.168.242.101:2379,http://127.0.0.1:2379
listen-peer-urls: http://192.168.242.101:2380
initial-advertise-peer-urls: http://192.168.242.101:2380
initial-cluster: etcd-1=http://192.168.242.101:2380,etcd-2=http://192.168.242.102:2380,etcd-3=http://192.168.242.103:2380
initial-cluster-token: etcd-cluster-token
initial-cluster-state: new
EOF
```

创建目录：
```
sudo mkdir -p /var/lib/etcd/
```

###  配置etcd service文件【antdb】

```shell
sudo cat > /usr/lib/systemd/system/etcd.service <<EOF
[Unit]
Description=Etcd Server
After=network.target
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
WorkingDirectory=/var/lib/etcd/
ExecStart=/bin/etcd --config-file=/etc/etcd/conf.yaml
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
```


### 关闭防火墙【root】

```
sudo systemctl stop firewalld.service
sudo systemctl disable firewalld.service
```

### 关闭 SELINUX【root】

* 查看状态
```
/usr/sbin/sestatus -v
```

* 临时关闭：
```
setenforce 0
```

* 修改配置文件关闭：
```
sudo vi /etc/selinux/config
将 SELINUX=enforcing 改为 SELINUX=disabled
```

### service方式启动etcd【antdb】

```shell
# 注意检查防火墙和selinux，避免以下错误： publish error: etcdserver: request timed out
sudo systemctl daemon-reload
sudo systemctl restart etcd
sudo systemctl status etcd
```

### 查看状态【antdb】

``` shell
# 时间不同步会有一些报错，但能正常部署并运行，实际环境中需要配置ntp时间同步
[root@Server1 ~]# sudo systemctl status etcd
● etcd.service - Etcd Server
   Loaded: loaded (/usr/lib/systemd/system/etcd.service; disabled; vendor preset: disabled)
   Active: active (running) since Mon 2019-12-16 01:03:59 EST; 24h ago
 Main PID: 41320 (etcd)
   CGroup: /system.slice/etcd.service
           └─41320 /bin/etcd --config-file=/etc/etcd/conf.yaml

Dec 16 18:45:41 Server1 etcd[41320]: failed to send out heartbeat on time (exceeded the 100ms timeout for 2.127838662s, to db179a449b6b0de8)
Dec 16 18:45:41 Server1 etcd[41320]: server is likely overloaded
Dec 16 18:45:41 Server1 etcd[41320]: failed to send out heartbeat on time (exceeded the 100ms timeout for 2.127879201s, to beef4df2df8a8cfc)
Dec 16 18:45:41 Server1 etcd[41320]: server is likely overloaded
Dec 16 19:45:21 Server1 etcd[41320]: failed to send out heartbeat on time (exceeded the 100ms timeout for 1.812316393s, to db179a449b6b0de8)
Dec 16 19:45:21 Server1 etcd[41320]: server is likely overloaded
Dec 16 19:45:21 Server1 etcd[41320]: failed to send out heartbeat on time (exceeded the 100ms timeout for 1.813021423s, to beef4df2df8a8cfc)
Dec 16 19:45:21 Server1 etcd[41320]: server is likely overloaded
Dec 16 19:45:28 Server1 etcd[41320]: the clock difference against peer db179a449b6b0de8 is too high [59m7.515068949s > 1s] (prober "ROUND_TRIPPER_RAFT_MESSAGE")
Dec 16 19:45:28 Server1 etcd[41320]: the clock difference against peer db179a449b6b0de8 is too high [59m7.518988151s > 1s] (prober "ROUND_TRIPPER_SNAPSHOT")

[root@Server1 ~]# etcdctl member list
beef4df2df8a8cfc: name=etcd-3 peerURLs=http://192.168.242.103:2380 clientURLs=http://127.0.0.1:2379,http://192.168.242.103:2379 isLeader=false
db179a449b6b0de8: name=etcd-2 peerURLs=http://192.168.242.102:2380 clientURLs=http://127.0.0.1:2379,http://192.168.242.102:2379 isLeader=false
eeaa227dea3a38d4: name=etcd-1 peerURLs=http://192.168.242.101:2380 clientURLs=http://127.0.0.1:2379,http://192.168.242.101:2379 isLeader=true
```

## Patroni 的配置与启动【antdb】

### 配置patroni参数【antdb】

```shell
# 不同节点需要修改对应的IP信息，以及开头的name信息
sudo vi /etc/patroni.yml 

# /namespace/scope/members/name
scope: test # level 2
namespace: /antdb5/  # level 1
name: node_74  # level 3 

restapi:  # https://github.com/zalando/patroni/blob/master/docs/SETTINGS.rst#rest-api
  listen: 127.0.0.1:8008  # 修改为实际地址
  connect_address: 127.0.0.1:8008 # 修改为实际地址

etcd:
  host: 192.168.242.103:2379

bootstrap:
  # this section will be written into Etcd:/<namespace>/<scope>/config after initializing new cluster
  # and all other cluster members will use it as a `global configuration`
  dcs:
    ttl: 15
    loop_wait: 5
    retry_timeout: 5
    maximum_lag_on_failover: 1048576
    master_start_timeout: 300
    synchronous_mode: true
    postgresql:
      use_pg_rewind: true
#     use_slots: true
      parameters:
         listen_addresses: "*"
         port: 5432
         wal_level: hot_standby
         log_directory: "pg_log"
         log_destination: "csvlog"
         hot_standby: "on"
         wal_keep_segments: 8
         max_wal_senders: 5


  # some desired options for 'initdb'
  initdb:  # Note: It needs to be a list (some options need values, others are switches)
  - encoding: UTF8
  - data-checksums

  pg_hba:  # Add following lines to pg_hba.conf after running 'initdb'
  - host replication replicator 192.168.242.0/24 trust
  - host all all 192.168.242.0/24 trust

  # Additional script to be launched after initial cluster creation (will be passed the connection URL as parameter)
# post_init: /usr/local/bin/setup_cluster.sh

  # Some additional users users which needs to be created after initializing new cluster
  users:
    admin:
      password: admin
      options:
        - createrole
        - createdb

postgresql:
  listen: 192.168.242.103:5432
  connect_address: 192.168.242.103:5432
  data_dir: /home/antdb/data/data_5.0
  bin_dir: /home/antdb/app/antdb_5.0/bin
  pgpass: /home/antdb/data/.pgpass
  authentication:
    replication:
      username: replicator
      password: antdb
    superuser:
      username: antdb
      password: antdb
  parameters:
    unix_socket_directories: '/tmp'

tags:
    nofailover: false
    noloadbalance: false
    clonefrom: false
    nosync: false
EOF
```

### 创建replicator用户【antdb】

```shell
psql -p 5432 

create role replicator with login replication password 'antdb';
alter role antdb password 'antdb';
```

###  配置patroni service文件【antdb】

> `ExecStart`后面的`patroni`需要在实际环境中通过 `which patroni` 获取绝对路径，并进行替换。

```shell
sudo cat > /usr/lib/systemd/system/patroni.service <<EOF

[Unit]
Description=Runners to orchestrate a high-availability AntDB5.0
After=syslog.target network.target

[Service]
Type=simple
User=antdb
Group=antdb
ExecStart=/usr/local/bin/patroni /etc/patroni.yml
KillMode=process
TimeoutSec=30
Restart=no

[Install]
WantedBy=multi-user.target
EOF
```

### service方式启动patroni

```shell
sudo systemctl daemon-reload
sudo systemctl start patroni
# sudo systemctl stop patroni
sudo systemctl status patroni -l

# patroni的日志在系统日志中：
tail -f /var/log/messages
```

### patronictl 查看集群信息

```shell
patronictl -c /etc/patroni.yml list 

+---------+----------+-----------------+--------------+---------+----+-----------+-----------------+
| Cluster |  Member  |       Host      |     Role     |  State  | TL | Lag in MB | Pending restart |
+---------+----------+-----------------+--------------+---------+----+-----------+-----------------+
|  pgtest | antdb5_1 | 192.168.242.101 |    Leader    | running |  1 |           |                 |
|  pgtest | antdb5_2 | 192.168.242.102 |              | running |  1 |         0 |        *        |
|  pgtest | antdb5_3 | 192.168.242.103 | Sync Standby | running |  1 |         0 |        *        |
+---------+----------+-----------------+--------------+---------+----+-----------+-----------------+
```

### patronictl常用命令

```shell
# 修改配置
export EDITOR=vi
patronictl -c /etc/patroni.yml edit-config pgtest

# 重启集群
patronictl -c /etc/patroni.yml restart pgtest

# 重启节点
patronictl -c /etc/patroni.yml restart pgtest antdb5_1
```

## 附录
###  patroni 通过服务启动报错分析
通过服务启动日志报错： systemctl start patroni
```log
May 29 12:07:05 template systemd: Started Runners to orchestrate a high-availability AntDB5.0.
May 29 12:07:05 template systemd: Starting Runners to orchestrate a high-availability AntDB5.0...
May 29 12:07:05 template patroni: FATAL: Patroni requires psycopg2>=2.5.4 or psycopg2-binary
May 29 12:07:05 template systemd: patroni.service: main process exited, code=exited, status=1/FAILURE
May 29 12:07:05 template systemd: Unit patroni.service entered failed state.
May 29 12:07:05 template systemd: patroni.service failed.
```


patroni 代码里的判断逻辑，根据报错位置，看样子是 import 报错：
```python
def main():
    min_psycopg2 = (2, 5, 4)
    
    min_psycopg2_str = '.'.join(map(str, min_psycopg2))

    def parse_version(version):
        for e in version.split('.'):
            try:
                yield int(e)
            except ValueError:
                break

    try:
        import psycopg2
        version_str = psycopg2.__version__.split(' ')[0]
        version = tuple(parse_version(version_str))
        if version < min_psycopg2:
            fatal('Patroni requires psycopg2>={0}, but only {1} is available', min_psycopg2_str, version_str)
    except ImportError:
        fatal('Patroni requires psycopg2>={0} or psycopg2-binary', min_psycopg2_str)
```

简单import 验证没有问题：
```shell
[antdb@test-node25 ~]$ python -c "import psycopg2; print(psycopg2.__version__)"
2.8.4 (dt dec pq3 ext lo64)
[antdb@test-node25 ~]$ sudo python -c "import psycopg2; print(psycopg2.__version__)"
2.8.4 (dt dec pq3 ext lo64)
```


单独验证也没有问题
```shell
[antdb@test-node25 danghb]$ sudo python t.py 
('Patroni requires psycopg2 version {0} available', '2.8.4')
[antdb@test-node25 danghb]$ cat t.py 
if __name__ == "__main__":    
    min_psycopg2 = (2, 5, 4)
    min_psycopg2_str = '.'.join(map(str, min_psycopg2))

    def parse_version(version):
        for e in version.split('.'):
            try:
                yield int(e)
            except ValueError:
                break

    try:
        import psycopg2
        version_str = psycopg2.__version__.split(' ')[0]
        version = tuple(parse_version(version_str))
        if version < min_psycopg2:
            print('Patroni requires psycopg2>={0}, but only {1} is available', min_psycopg2_str, version_str)
        else:
           print('Patroni requires psycopg2 version {0} available', version_str)
    except ImportError:
        print('Patroni requires psycopg2>={0} or psycopg2-binary', min_psycopg2_str)
[antdb@test-node25 danghb]$ 
```



手动启动patroni：patroni /etc/patroni.yml
```log
2020-05-29 12:59:39,173 INFO: Lock owner: None; I am node1
2020-05-29 12:59:39,187 INFO: Lock owner: None; I am node1
2020-05-29 12:59:39,192 INFO: starting as a secondary
2020-05-29 12:59:39,231 INFO: postmaster pid=68565
2020-05-29 12:59:39.240 CST [68565] LOG:  listening on IPv4 address "10.238.99.74", port 5432
2020-05-29 12:59:39.241 CST [68565] LOG:  listening on Unix socket "/tmp/.s.PGSQL.5432"
2020-05-29 12:59:39.450 CST [68565] LOG:  redirecting log output to logging collector process
2020-05-29 12:59:39.450 CST [68565] HINT:  Future log output will appear in directory "pg_log".
10.238.99.74:5432 - rejecting connections
10.238.99.74:5432 - accepting connections
2020-05-29 12:59:39,513 INFO: establishing a new patroni connection to the postgres cluster
2020-05-29 12:59:39,526 WARNING: Could not activate Linux watchdog device: "Can't open watchdog device: [Errno 2] No such file or directory: '/dev/watchdog'"
2020-05-29 12:59:39,537 INFO: promoted self to leader by acquiring session lock
server promoting
2020-05-29 12:59:39,545 INFO: cleared rewind state after becoming the leader
2020-05-29 12:59:40,611 INFO: Lock owner: node1; I am node1
2020-05-29 12:59:40,638 INFO: no action.  i am the leader with the lock
2020-05-29 12:59:45,612 INFO: Lock owner: node1; I am node1
2020-05-29 12:59:45,627 INFO: no action.  i am the leader with the lock
2020-05-29 12:59:50,615 INFO: Lock owner: node1; I am node1
2020-05-29 12:59:50,638 INFO: no action.  i am the leader with the lock
2020-05-29 12:59:55,613 INFO: Lock owner: node1; I am node1
```

也没有问题，怀疑是服务文件这块，没有加载一些环境变量。


将验证脚本写到服务里：
```shell
sudo vi /usr/lib/systemd/system/dangtest.service 
[Unit]
Description=dangtest
After=syslog.target network.target

[Service]
Type=simple
User=antdb
Group=antdb
ExecStart=/usr/bin/python /home/antdb/danghb/t.py
KillMode=process

[Install]
WantedBy=multi-user.target
```

sudo systemctl daemon-reload
sudo systemctl start dangtest

```log
May 29 13:49:10 template systemd: Started dangtest.
May 29 13:49:10 template systemd: Starting dangtest...
May 29 13:49:10 template python: ('Patroni requires psycopg2>={0} or psycopg2-binary', '2.5.4')
```

Systemd starts the processes with a minimal environment

通过systemd 果然不行。

通过systemd 的输出跟下面类似：
```log
[antdb@test-node25 ~]$ env -i /usr/bin/python /home/antdb/danghb/t.py
('Patroni requires psycopg2>={0} or psycopg2-binary', '2.5.4')
[antdb@test-node25 ~]$  /usr/bin/python /home/antdb/danghb/t.py
('Patroni requires psycopg2 version {0} available', '2.8.4')
```
也就是没有加载环境变量。

指定`PYTHONPATH`:
```log
[antdb@test-node25 ~]$ env  PYTHONPATH=/usr/lib64/python2.7/site-packages /usr/bin/python /home/antdb/danghb/t.py
('Patroni requires psycopg2 version {0} available', '2.8.4')
[antdb@test-node25 ~]$ sudo env  PYTHONPATH=/usr/lib64/python2.7/site-packages /usr/bin/python /home/antdb/danghb/t.py
('Patroni requires psycopg2 version {0} available', '2.8.4')
```

再次修改 dangtest.service 文件中,添加 `Environment`选项：
```
sudo vi /usr/lib/systemd/system/dangtest.service 
Environment=PYTHONPATH=/usr/lib64/python2.7/site-packages 
ExecStart=”/usr/bin/python /home/antdb/danghb/t.py
```
不起作用.
修改 `ExecStart` 为：
```
ExecStart=/usr/bin/env  PYTHONPATH=/usr/lib64/python2.7/site-packages /usr/bin/python /home/antdb/danghb/t.py
```
也不起作用

sudo systemctl daemon-reload
sudo systemctl start dangtest



考虑到执行直接脚本正常，且通过 `env -i` 异常，那这之间肯定用到了用户的一些环境变量，
```
sudo vi /etc/antdb_env.conf
SELINUX_ROLE_REQUESTED=
TERM=vt100
SHELL=/bin/bash
HISTSIZE=5
PERL5LIB=/home/antdb/perl5/lib64/perl5:/home/antdb/perl5/usr/local/share/perl5/:
SELINUX_USE_CURRENT_RANGE=
ADB_HOME=/data/antdb/app/antdb
SSH_TTY=/dev/pts/30
USER=antdb
PGPORT=5432
LD_LIBRARY_PATH=/data/antdb/app/antdb/lib:/data/antdb/oracle/instantclient_11_2:
LS_COLORS=rs=0:di=01;34:ln=01;36:mh=00:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:mi=01;05;37;41:su=37;41:sg=30;43:ca=30;41:tw=30;42:ow=34;42:st=37;44:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arc=01;31:*.arj=01;31:*.taz=01;31:*.lha=01;31:*.lz4=01;31:*.lzh=01;31:*.lzma=01;31:*.tlz=01;31:*.txz=01;31:*.tzo=01;31:*.t7z=01;31:*.zip=01;31:*.z=01;31:*.Z=01;31:*.dz=01;31:*.gz=01;31:*.lrz=01;31:*.lz=01;31:*.lzo=01;31:*.xz=01;31:*.bz2=01;31:*.bz=01;31:*.tbz=01;31:*.tbz2=01;31:*.tz=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.war=01;31:*.ear=01;31:*.sar=01;31:*.rar=01;31:*.alz=01;31:*.ace=01;31:*.zoo=01;31:*.cpio=01;31:*.7z=01;31:*.rz=01;31:*.cab=01;31:*.jpg=01;35:*.jpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.svg=01;35:*.svgz=01;35:*.mng=01;35:*.pcx=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.m2v=01;35:*.mkv=01;35:*.webm=01;35:*.ogm=01;35:*.mp4=01;35:*.m4v=01;35:*.mp4v=01;35:*.vob=01;35:*.qt=01;35:*.nuv=01;35:*.wmv=01;35:*.asf=01;35:*.rm=01;35:*.rmvb=01;35:*.flc=01;35:*.avi=01;35:*.fli=01;35:*.flv=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.yuv=01;35:*.cgm=01;35:*.emf=01;35:*.axv=01;35:*.anx=01;35:*.ogv=01;35:*.ogx=01;35:*.aac=01;36:*.au=01;36:*.flac=01;36:*.mid=01;36:*.midi=01;36:*.mka=01;36:*.mp3=01;36:*.mpc=01;36:*.ogg=01;36:*.ra=01;36:*.wav=01;36:*.axa=01;36:*.oga=01;36:*.spx=01;36:*.xspf=01;36:
PGDATABASE=postgres
MAIL=/var/spool/mail/antdb
PATH=/data/antdb/app/antdb/bin:/data/antdb/oracle/instantclient_11_2:/home/antdb/perl5/usr/local/bin/:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/home/antdb/.local/bin:/home/antdb/bin
PWD=/home/antdb
LANG=en_US.UTF-8
SELINUX_LEVEL_REQUESTED=
HISTCONTROL=ignoredups
SHLVL=1
HOME=/home/antdb
LOGNAME=antdb
PGDATA=/data/antdb/data/antdb
LESSOPEN=||/usr/bin/lesspipe.sh %s
XDG_RUNTIME_DIR=/run/user/1012
ORACLE_HOME=/data/antdb/oracle/instantclient_11_2
_=/usr/bin/env
```


修改 `EnvironmentFile` 为：
```
EnvironmentFile=/etc/antdb_env.conf
```

启动 `dangtest` 服务，终于好了：
```
May 29 15:32:25 template systemd: Configuration file /usr/lib/systemd/system/dangtest.service is marked world-inaccessible. This has no effect as configuration data is accessible via APIs without restrictions. Proceeding anyway.
May 29 15:32:25 template systemd: Started dangtest.
May 29 15:32:25 template systemd: Starting dangtest...
May 29 15:32:25 template python: ('Patroni requires psycopg2 version {0} available', '2.8.4'
```

同样的，修改 patroni 的 service 文件:
```
[antdb@test-node25 ~]$ sudo vi /usr/lib/systemd/system/patroni.service 
[Unit]
Description=Runners to orchestrate a high-availability AntDB5.0
After=syslog.target network.target

[Service]
Type=simple
User=antdb
Group=antdb
EnvironmentFile=/etc/antdb_env.conf
ExecStart=/usr/bin/patroni /etc/patroni.yml
#KillMode=mixed
TimeoutSec=30
Restart=no

[Install]
WantedBy=multi-user.target
```
再次通过服务方式去启动 patroni:
```log
sudo systemctl start patroni

日志：
May 29 15:56:04 template patroni: 2020-05-29 15:56:04.165 CST [69645] LOG:  listening on Unix socket "/tmp/.s.PGSQL.5432"
May 29 15:56:04 template patroni: 2020-05-29 15:56:04.325 CST [69645] LOG:  redirecting log output to logging collector process
May 29 15:56:04 template patroni: 2020-05-29 15:56:04.325 CST [69645] HINT:  Future log output will appear in directory "pg_log".
May 29 15:56:04 template patroni: 10.238.99.74:5432 - rejecting connections
May 29 15:56:04 template patroni: 10.238.99.74:5432 - accepting connections
May 29 15:56:04 template patroni: 2020-05-29 15:56:04,397 INFO: establishing a new patroni connection to the postgres cluster
May 29 15:56:04 template patroni: 2020-05-29 15:56:04,421 WARNING: Could not activate Linux watchdog device: "Can't open watchdog device: [Errno 2] No such file or directory: '/dev/watchdog'"
May 29 15:56:04 template patroni: 2020-05-29 15:56:04,443 INFO: promoted self to leader by acquiring session lock
May 29 15:56:04 template patroni: server promoting
May 29 15:56:04 template patroni: 2020-05-29 15:56:04,454 INFO: cleared rewind state after becoming the leader
May 29 15:56:05 template patroni: 2020-05-29 15:56:05,528 INFO: Lock owner: node1; I am node1
May 29 15:56:05 template patroni: 2020-05-29 15:56:05,565 INFO: no action.  i am the leader with the lock
May 29 15:56:10 template patroni: 2020-05-29 15:56:10,526 INFO: Lock owner: node1; I am node1
May 29 15:56:10 template patroni: 2020-05-29 15:56:10,536 INFO: no action.  i am the leader with the lock
```


启动正常。

参考链接：
* https://wizardforcel.gitbooks.io/vbird-linux-basic-4e/content/150.html
* https://stackoverflow.com/questions/35641414/python-import-of-local-module-failing-when-run-as-systemd-systemctl-service