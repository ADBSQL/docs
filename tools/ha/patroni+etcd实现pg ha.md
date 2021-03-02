#### 准备工作

##### 主机环境

| 主机IP       | 安装组件           |
| ------------ | ------------------ |
| 10.21.20.175 | pg9.6+patroni+etcd |
| 10.21.20.176 | pg9.6+patroni      |
|              |                    |

##### 创建用户

```shell
root:
useradd dangpg
passwd dangpg
# 添加 dangpg到sudo 中
visudo

dangpg ALL=(ALL) NOPASSWD: ALL
```

##### 创建必要的目录

```shell
su - dangpg
mkdir -p ~/{app,data,scripts,tools,soft_src}
```

#### 安装软件

##### 安装postgresql

```shell
mkdir -p ~/app/{pg96,pg10}
mkdir -p ~/data/{pg96,pg10}
cd soft_src
# 安装pg9.6.9
wget http://mirrors.zju.edu.cn/postgresql/source/v9.6.9/postgresql-9.6.9.tar.gz
tar xzvf postgresql-9.6.9.tar.gz
cd postgresql-9.6.9
./configure --prefix=/home/dangpg/app/pg96
make
make install
# 添加环境变量, vi ~/.bashrc
export PGHOME=$HOME/app/pg96
export PGDATA=$HOME/data/pg96
export PGPORT=23969
export PGDATABASE=postgres
export PATH=$PGHOME/bin:$PATH

source ~/.bashrc
[dangpg@intel175 ~]$  which postgres
~/app/pg96/bin/postgres
```

##### 安装patrnoni

```shell
cd soft_src
sudo pip install --upgrade setuptools
git clone https://github.com/zalando/patroni.git
cd patroni
sudo pip uninstall -y -r ./requirements.txt
sudo pip uninstall -y psycopg2-binary
sudo pip install psycopg2-binary
sudo pip install -r ./requirements.txt
sudo pip install patroni 
# python setup.py install --user     # 安装到当前用户
....

[dangpg@intel175 patroni]$ which patroni
/bin/patroni
```

#####  安装etcd

```
sudo yum -y install etcd
```

#### 配置相关参数文件

##### 配置etcd 参数

```yaml
sudo vi /etc/etcd/conf.yaml

name: etcd-1  
data-dir: /var/lib/etcd/data
listen-client-urls: http://10.21.20.176:2379,http://127.0.0.1:2379  
advertise-client-urls: http://10.21.20.176:2379,http://127.0.0.1:2379  
listen-peer-urls: http://10.21.20.176:2380  
initial-advertise-peer-urls: http://10.21.20.176:2380  
initial-cluster: etcd-1=http://10.21.20.176:2380 
initial-cluster-token: etcd-cluster-token  
initial-cluster-state: new  
```

#####  配置service 文件

```
sudo vi /usr/lib/systemd/system/etcd.service
[Unit]
Description=Etcd Server
After=network.target
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
WorkingDirectory=/var/lib/etcd/
#EnvironmentFile=-/etc/etcd/etcd.conf
#User=etcd
# set GOMAXPROCS to number of processors
#ExecStart=/bin/bash -c "GOMAXPROCS=$(nproc) /bin/etcd --name=\"${ETCD_NAME}\" --data-dir=\"${ETCD_DATA_DIR}\" --listen-client-urls=\"${ETCD_LISTEN_CLIENT_URLS}\""
ExecStart=/bin/etcd --config-file=/etc/etcd/conf.yaml
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```

##### service 方式启动etcd

```
sudo systemctl daemon-reload
sudo systemctl restart etcd
sudo systemctl status etcd
```

##### 查看状态

```
[dangpg@intel176 etcd]$ sudo systemctl status etcd
● etcd.service - Etcd Server
   Loaded: loaded (/usr/lib/systemd/system/etcd.service; enabled; vendor preset: disabled)
   Active: active (running) since Sun 2018-06-24 18:56:19 CST; 21s ago
 Main PID: 57333 (etcd)
   CGroup: /system.slice/etcd.service
           └─57333 /bin/etcd --config-file=/etc/etcd/conf.yaml

Jun 24 18:56:19 intel176 etcd[57333]: raft.node: 795c6b10dd57cd1d elected leader 795c6b10dd57cd1d at term 2
Jun 24 18:56:19 intel176 etcd[57333]: setting up the initial cluster version to 3.2
Jun 24 18:56:19 intel176 etcd[57333]: set the initial cluster version to 3.2
Jun 24 18:56:19 intel176 etcd[57333]: ready to serve client requests
Jun 24 18:56:19 intel176 etcd[57333]: enabled capabilities for version 3.2
Jun 24 18:56:19 intel176 etcd[57333]: published {Name:etcd-1 ClientURLs:[http://10.21.20.176:3379 http://127.0.0.1:3379...e809e94
Jun 24 18:56:19 intel176 etcd[57333]: ready to serve client requests
Jun 24 18:56:19 intel176 systemd[1]: Started Etcd Server.
Jun 24 18:56:19 intel176 etcd[57333]: serving insecure client requests on 10.21.20.176:3379, this is strongly discouraged!
Jun 24 18:56:19 intel176 etcd[57333]: serving insecure client requests on 127.0.0.1:3379, this is strongly discouraged!
Hint: Some lines were ellipsized, use -l to show in full.

[dangpg@intel176 etcd]$ etcdctl member list
795c6b10dd57cd1d: name=etcd-1 peerURLs=http://10.21.20.176:3380 clientURLs=http://10.21.20.176:2379,http://127.0.0.1:2379 isLeader=true
```

##### 配置patroni参数

```yaml
 mkdir -p ~/tools/patroni/{log,conf}
[dangpg@intel175 conf]$ cat pg1.yml 
scope: pgtest
namespace: /pg96/
name: pg1

restapi:
  # 节点之间的api操作需要通过以下配置去完成通信，当listen和connect_address配置为127.0.0.1时，api只能操作本节点，
  # 当需要完成switchover、failover等时，需要配置节点间可以访问的地址
  #listen: 127.0.0.1:8008
  #connect_address: 127.0.0.1:8008
  listen: 10.21.20.176:8008
  connect_address: 10.21.20.176:8008

etcd:
  host: 10.21.20.176:2379

bootstrap:
  # this section will be written into Etcd:/<namespace>/<scope>/config after initializing new cluster
  # and all other cluster members will use it as a `global configuration`
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 10
    maximum_lag_on_failover: 1048576
#   master_start_timeout: 300
#   synchronous_mode: false
    postgresql:
      use_pg_rewind: true
#     use_slots: true
      parameters:
         listen_addresses: "*"
         port: 23969
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
  - host replication replicator 0.0.0.0/0 trust
  - host all all 0.0.0.0/0 md5
  - host all all 0.0.0.0/0 trust
#  - hostssl all all 0.0.0.0/0 md5

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
  listen: 10.21.20.175:23969
  connect_address: 10.21.20.175:23969
  data_dir: /home/dangpg/data/pg96
  bin_dir: /home/dangpg/app/pg96/bin
  pgpass: /tmp/pgpass0
  authentication:
    replication:
      username: replicator
      password: dangpg
    superuser:
      username: dangpg
      password: dangpg
  parameters:
    unix_socket_directories: '/tmp'

tags:
    nofailover: false
    noloadbalance: false
    clonefrom: false
    nosync: false
```

##### 启动patroni

```
patroni /home/dangpg/tools/patroni/conf/pg1.yml
export PATRONI_CONFIGURATION=/home/dangpg/tools/patroni/conf/pg1.yml
# 后台启动：
nohup patroni /home/dangpg/tools/patroni/conf/pg1.yml >> /home/dangpg/tools/patroni/log/pg1.log 2>&1 &
```

##### 查看状态

```
[dangpg@intel175 pg96]$ curl http://127.0.0.1:8008|jq
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   271    0   271    0     0  45815      0 --:--:-- --:--:-- --:--:-- 54200
{
  "database_system_identifier": "6570636946718254372",
  "postmaster_start_time": "2018-06-24 21:13:46.074 CST",
  "timeline": 4,
  "xlog": {
    "location": 24526456
  },
  "patroni": {
    "scope": "pgtest",
    "version": "1.4.4"
  },
  "state": "running",
  "role": "master",
  "server_version": 90609
}
```

##### 添加备节点

```
chmod 700  /home/dangpg/data/pg96
export PATRONI_CONFIGURATION=/home/dangpg/scripts/pg2.yml
[dangpg@intel176 scripts]$ patroni /home/dangpg/scripts/pg2.yml
2018-06-24 21:26:12,555 INFO: Selected new etcd server http://10.21.20.176:2379
2018-06-24 21:26:12,569 INFO: Lock owner: pg1; I am pg2
2018-06-24 21:26:12,571 INFO: trying to bootstrap from leader 'pg1'
WARNING:  skipping special file "./.s.PGSQL.23969"
2018-06-24 21:26:14,828 INFO: replica has been created using basebackup
2018-06-24 21:26:14,830 INFO: bootstrapped from leader 'pg1'
2018-06-24 21:26:15,181 INFO: postmaster pid=62729
LOG:  ending log output to stderr
HINT:  Future log output will go to log destination "csvlog".
LOG:  database system was interrupted; last known up at 2018-06-24 21:26:11 CST
FATAL:  the database system is starting up
10.21.20.176:23969 - rejecting connections
FATAL:  the database system is starting up
10.21.20.176:23969 - rejecting connections
LOG:  entering standby mode
LOG:  redo starts at 0/4000028
LOG:  consistent recovery state reached at 0/40000F8
LOG:  database system is ready to accept read only connections
LOG:  started streaming WAL from primary at 0/5000000 on timeline 4
10.21.20.176:23969 - accepting connections
2018-06-24 21:26:16,256 INFO: Lock owner: pg1; I am pg2
2018-06-24 21:26:16,257 INFO: does not have lock
2018-06-24 21:26:16,257 INFO: establishing a new patroni connection to the postgres cluster
2018-06-24 21:26:16,277 INFO: no action.  i am a secondary and i am following a leader
2018-06-24 21:26:18,046 INFO: Lock owner: pg1; I am pg2
2018-06-24 21:26:18,046 INFO: does not have lock
2018-06-24 21:26:18,050 INFO: no action.  i am a secondary and i am following a leader
2018-06-24 21:26:28,047 INFO: Lock owner: pg1; I am pg2
2018-06-24 21:26:28,048 INFO: does not have lock
2018-06-24 21:26:28,051 INFO: no action.  i am a secondary and i am following a leader
2018-06-24 21:26:38,046 INFO: Lock owner: pg1; I am pg2
```

##### 查看备节点状态

```
[dangpg@intel176 ~]$ curl http://127.0.0.1:8008|jq
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   357    0   357    0     0  56532      0 --:--:-- --:--:-- --:--:-- 59500
{
  "database_system_identifier": "6570636946718254372",
  "postmaster_start_time": "2018-06-24 21:26:15.187 CST",
  "timeline": 4,
  "xlog": {
    "received_location": 83886176,
    "replayed_timestamp": null,
    "paused": false,
    "replayed_location": 83886176
  },
  "patroni": {
    "scope": "pgtest",
    "version": "1.4.4"
  },
  "state": "running",
  "role": "replica",
  "server_version": 90609
}
```

##### patronictl 查看集群信息

```
[dangpg@intel175 conf]$ patronictl  -c pg1.yml list
+---------+--------+--------------+--------+---------+-----------+
| Cluster | Member |     Host     |  Role  |  State  | Lag in MB |
+---------+--------+--------------+--------+---------+-----------+
|  pgtest |  pg1   | 10.21.20.175 |        | running |       0.0 |
|  pgtest |  pg2   | 10.21.20.176 | Leader | running |       0.0 |
|  pgtest |  pg3   | 10.1.226.201 |        | running |       0.0 |
+---------+--------+--------------+--------+---------+-----------+
```

##### patronictl 修改参数

```
[dangpg@intel176 conf]$ export EDITOR=vi
[dangpg@intel176 conf]$ patronictl -c pg2.yml edit-config pgtest
loop_wait: 10
maximum_lag_on_failover: 1048576
postgresql:
  parameters:
    hot_standby: 'on'
    listen_addresses: '*'
    log_destination: csvlog
    log_directory: pg_log
    max_wal_senders: 5
    port: 23969
    wal_keep_segments: 8
    wal_level: hot_standby
    unix_socket_directories: "/tmp"
  use_pg_rewind: true
retry_timeout: 10
ttl: 30
~
"/tmp/pgtest-config-wmQpVP.yaml" 16L, 350C written
--- 
+++ 
@@ -10,6 +10,7 @@
     port: 23969
     wal_keep_segments: 8
     wal_level: hot_standby
+    unix_socket_directories: "/tmp"
   use_pg_rewind: true
 retry_timeout: 10
 ttl: 30

Apply these changes? [y/N]: y
Configuration changed
```

##### patroni 重启节点

```
[dangpg@intel176 conf]$ patronictl -c pg2.yml restart pgtest pg2
+---------+--------+--------------+--------+---------+-----------+
| Cluster | Member |     Host     |  Role  |  State  | Lag in MB |
+---------+--------+--------------+--------+---------+-----------+
|  pgtest |  pg1   | 10.21.20.175 |        | running |       0.0 |
|  pgtest |  pg2   | 10.21.20.176 | Leader | running |       0.0 |
|  pgtest |  pg3   | 10.1.226.201 |        | running |       0.0 |
+---------+--------+--------------+--------+---------+-----------+
Are you sure you want to restart members pg2? [y/N]: y
Restart if the PostgreSQL version is less than provided (e.g. 9.5.2)  []: 
When should the restart take place (e.g. 2015-10-01T14:30)  [now]: 
Success: restart on member pg2
[dangpg@intel176 conf]$ 
```



##### etcd 查看集群信息

```
[dangpg@intel176 pg96]$ etcdctl get /pg96/pgtest/members/pg1|jq
{
  "conn_url": "postgres://10.21.20.175:23969/postgres",
  "api_url": "http://127.0.0.1:8008/patroni",
  "timeline": 8,
  "state": "running",
  "role": "replica",
  "xlog_location": 83888384
}
[dangpg@intel176 pg96]$ etcdctl get /pg96/pgtest/members/pg2|jq
{
  "conn_url": "postgres://10.21.20.176:23969/postgres",
  "api_url": "http://127.0.0.1:8008/patroni",
  "timeline": 8,
  "state": "running",
  "role": "master",
  "xlog_location": 83888608
}

[dangpg@intel176 pg96]$ etcdctl get /pg96/pgtest/config|jq
{
  "ttl": 30,
  "maximum_lag_on_failover": 1048576,
  "retry_timeout": 10,
  "postgresql": {
    "use_pg_rewind": true,
    "parameters": {
      "log_destination": "csvlog",
      "hot_standby": "on",
      "log_directory": "pg_log",
      "listen_addresses": "*",
      "wal_keep_segments": 8,
      "wal_level": "hot_standby",
      "max_wal_senders": 5,
      "port": 23969
    }
  },
  "loop_wait": 10
}

[dangpg@intel176 pg96]$ etcdctl get /pg96/pgtest/leader
pg2

[dangpg@intel176 pg96]$ etcdctl get /pg96/pgtest/optime/leader
83888608

[dangpg@intel176 pg96]$ etcdctl get /pg96/pgtest/initialize
6570636946718254372

[dangpg@intel176 pg96]$ etcdctl get /pg96/pgtest/history|jq
[
  [
    1,
    24525192,
    "no recovery target specified",
    "2018-06-24T21:08:09+08:00"
  ],
  [
    2,
    24525576,
    "no recovery target specified",
    "2018-06-24T21:12:58+08:00"
  ],
  [
    3,
    24525960,
    "no recovery target specified",
    "2018-06-24T21:13:46+08:00"
  ],
  [
    4,
    83886512,
    "no recovery target specified",
    "2018-06-24T21:31:47+08:00"
  ],
  [
    5,
    83886896,
    "no recovery target specified",
    "2018-06-24T21:32:56+08:00"
  ],
  [
    6,
    83887280,
    "no recovery target specified",
    "2018-06-24T21:35:21+08:00"
  ],
  [
    7,
    83888112,
    "no recovery target specified",
    "2018-06-24T21:47:03+08:00"
  ]
]
```

#### 问题处理

##### 清空etcd 配置

```
删除  etcd
```

##### 删除master pg_xlog，不切换



#### 优化点

- list 显示增加：port、sync_state
- slave的patroni停止后，在list 列表中消失，从patroni中不能判断slave其实已经down
- 主机上的每个patroni用watchdog 监控拉起
- patroni 主进程日志如何清理
- master 的VIP 谁来提供？haproxy

#### 针对antdb需要修改的点

- 在adbmgr init all 之后在各个主机上启动patroni进程
- 节点较多的时候patroni 配置文件如何生成
- 节点切换后，adbmgr如何知道最新的集群架构
- 