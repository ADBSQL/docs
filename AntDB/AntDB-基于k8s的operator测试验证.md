# AntDB 基于k8s的operator测试验证
***
本文主要探讨AntDB基于k8s通过operator的测试方案验证。

通过本文测试验证operator提供的下述功能点：

* master 节点clone
* slave 节点扩大/缩小节点数
* 集群 手工failover
* 数据库 backup/restore
* 数据库 版本升级(升级前后版本需兼容，且在停机状态下升级)

额外提供的功能点：

* 集群中master节点提供一个独立CLUSTER IP，slave组所有节点提供一个独立CLUSTER IP
* 集成pgbouncer ，提供连接池和负载均衡能力。结合CLUSTER IP + pgboucer，提供缓存池的同时，实现读写分离 + slave节点负载均衡
* initdb时，数据库参数可指定配置
* 集群自动failover

***

# 版本说明
|postgres-operator 服务端版本|4.2.1|https://github.com/CrunchyData/postgres-operator/tree/v4.2.1|
|:-----|:-------|:-------|
|postgres-operator 客户端版本(pgo)|4.2.1|https://github.com/CrunchyData/postgres-operator/releases/download/v4.2.1/postgres-operator.4.2.1.tar.gz|
|kubernetes 版本|1.13+||
|docker 版本|18.09.8||
|go 版本|1.13.7|https://dl.google.com/go/go1.13.7.linux-amd64.tar.gz|
|expenv 版本|1.2.0|https://github.com/blang/expenv，expenv已在pgo客户端版本集成，但不用单独安装，直接安装pgo即可|
|AntDB 版本(升级前)|PostgreSQL 11.5 ADB 4.1devel 461fafc|已编译pgaudit插件的单机版，对应镜像antdb-ha:4.0 |
|AntDB 版本(升级后)|PostgreSQL 11.5 ADB 4.1devel d5cbd85|已编译pgaudit插件的单机版，对应镜像antdb-ha:6.0 |
|pgaudit 版本|1.3.0|https://github.com/pgaudit/pgaudit/archive/1.3.0.zip|
|容器内os 版本|centos7||

# 需要准备的镜像

**AntDB相关镜像：**

* antdb-ha

antdb-ha替换crunchydata官方的crunchy-postgres-ha镜像。其他镜像，全部使用官方默认镜像即可。

# 功能测试
## 0. 环境准备
* 清理k8s环境
```
# cd $PGOROOT
# pwd
/data/pgo/odev/src/github.com/crunchydata/postgres-operator-4.2.1
# make cleannamespaces
cd deploy && ./cleannamespaces.sh
deleting the namespaces the operator is deployed into (pgo)...
namespace pgo deleted

deleting the watched namespaces...
namespace "pgouser1" deleted
namespace "pgouser2" deleted
```

* 清理并重建pv持久卷
```
# cd $PGOROOT
# ./pv/create-pv.sh 
create the test PV and PVC using the HostPath dir
creating PV crunchy-pv1
warning: deleting cluster-scoped resources, not scoped to the provided namespace
persistentvolume "crunchy-pv1" deleted
persistentvolume/crunchy-pv1 created
······
creating PV crunchy-pv20
warning: deleting cluster-scoped resources, not scoped to the provided namespace
persistentvolume "crunchy-pv20" deleted
persistentvolume/crunchy-pv20 created
# kubectl get pv
NAME           CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM   STORAGECLASS   REASON   AGE
crunchy-pv1    1Gi        RWX            Retain           Available                                   66s
crunchy-pv10   1Gi        RWX            Retain           Available                                   62s
crunchy-pv11   1Gi        RWX            Retain           Available                                   61s
crunchy-pv12   1Gi        RWX            Retain           Available                                   61s
crunchy-pv13   1Gi        RWX            Retain           Available                                   60s
crunchy-pv14   1Gi        RWX            Retain           Available                                   60s
crunchy-pv15   1Gi        RWX            Retain           Available                                   60s
crunchy-pv16   1Gi        RWX            Retain           Available                                   59s
crunchy-pv17   1Gi        RWX            Retain           Available                                   59s
crunchy-pv18   1Gi        RWX            Retain           Available                                   58s
crunchy-pv19   1Gi        RWX            Retain           Available                                   58s
crunchy-pv2    1Gi        RWX            Retain           Available                                   65s
crunchy-pv20   1Gi        RWX            Retain           Available                                   58s
crunchy-pv3    1Gi        RWX            Retain           Available                                   65s
crunchy-pv4    1Gi        RWX            Retain           Available                                   64s
crunchy-pv5    1Gi        RWX            Retain           Available                                   64s
crunchy-pv6    1Gi        RWX            Retain           Available                                   64s
crunchy-pv7    1Gi        RWX            Retain           Available                                   63s
crunchy-pv8    1Gi        RWX            Retain           Available                                   63s
crunchy-pv9    1Gi        RWX            Retain           Available                                   62s
```

* 新建AntDB k8s operator环境
-- 新建 k8s operator环境
```
# make setupnamespaces
cd deploy && ./setupnamespaces.sh
creating pgo namespace to deploy the Operator into...
namespace pgo created

creating namespaces for the Operator to watch and create PG clusters into...
namespace pgouser1 creating...
Error from server (NotFound): namespaces "pgouser1" not found
error: 'pgo-created-by' already has a value (add-script), and --overwrite is false
error: 'vendor' already has a value (crunchydata), and --overwrite is false
error: 'pgo-installation-name' already has a value (devtest), and --overwrite is false
namespace pgouser2 creating...
Error from server (NotFound): namespaces "pgouser2" not found
error: 'pgo-created-by' already has a value (add-script), and --overwrite is false
error: 'vendor' already has a value (crunchydata), and --overwrite is false
error: 'pgo-installation-name' already has a value (devtest), and --overwrite is false
[root@centos76-1 postgres-operator-4.2.1]# $PGOROOT/deploy/install-bootstrap-creds.sh
secret/pgorole-pgoadmin created
secret/pgouser-pgoadmin created
[root@centos76-1 postgres-operator-4.2.1]# make installrbac
cd deploy && ./install-rbac.sh
clusterrole.rbac.authorization.k8s.io "pgo-cluster-role" deleted
  ./install-rbac.sh: line 20: oc: command not found
secret "pgorole-pgoadmin" deleted
secret/pgorole-pgoadmin created
secret "pgouser-pgoadmin" deleted
secret/pgouser-pgoadmin created
clusterrole.rbac.authorization.k8s.io/pgo-cluster-role created
serviceaccount/postgres-operator created
clusterrolebinding.rbac.authorization.k8s.io/pgo-cluster-role created
role.rbac.authorization.k8s.io/pgo-role created
rolebinding.rbac.authorization.k8s.io/pgo-role created
Generating a 2048 bit RSA private key
..........................................................+++
................................................................................................................................+++
writing new private key to '/data/pgo/odev/src/github.com/crunchydata/postgres-operator-4.2.1/conf/postgres-operator/server.key'
-----
Generating public/private rsa key pair.
/data/pgo/odev/src/github.com/crunchydata/postgres-operator-4.2.1/conf/pgo-backrest-repo/ssh_host_rsa_key already exists.
Overwrite (y/n)? y
[root@centos76-1 postgres-operator-4.2.1]# make deployoperator
cd deploy && ./deploy.sh
secret/pgo-backrest-repo-config created
secret/pgo.tls created
configmap/pgo-config created
deployment.apps/postgres-operator created
service/postgres-operator created
[root@centos76-1 postgres-operator-4.2.1]# kubectl get service postgres-operator -n pgo
NAME                TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
postgres-operator   ClusterIP   10.98.103.143   <none>        8443/TCP,4171/TCP,4150/TCP   10s
[root@centos76-1 postgres-operator-4.2.1]# kubectl get pod --selector=name=postgres-operator -n pgo
NAME                                 READY   STATUS    RESTARTS   AGE
postgres-operator-576cc8f865-fm5m7   4/4     Running   0          19s
```

-- 调整k8s API的接口ip地址的环境变量
```
# vim ~/.bashrc
export PGO_APISERVER_URL=https://10.98.103.143:8443
# source ~/.bashrc
```
-- 为AntDB的应用新建k8s的用户
```
# vim ~/.pgouser
pgoadmin:examplepassword
# pgo create pgouser someuser --pgouser-namespaces="pgouser1,pgouser2" --pgouser-password=somepassword --pgouser-roles="pgoadmin"
Created pgouser.
# vim ~/.pgouser
someuser:somepassword
# pgo version
pgo client version 4.2.1
pgo-apiserver version 4.2.1
# kubectl get pod -n pgouser1
No resources found in pgouser1 namespace.
```

-- 搭建AntDB 的k8s operator集群(antdb-ha:4.0 的一个镜像，AntDB的git commit号是461fafc)
```
# pgo create cluster antdb  --ccp-image=antdb-ha --ccp-image-tag=4.0 --namespace=pgouser1 --replica-count=2
created Pgcluster antdb
workflow id 51c9c73c-85dd-4f71-bf1f-c48b62fa6791

-- submit 时间
# pgo show workflow 51c9c73c-85dd-4f71-bf1f-c48b62fa6791 -n pgouser1
parameter           value
---------           -----
pg-cluster          antdb
task submitted      2020-03-12T04:44:57Z
workflowid          51c9c73c-85dd-4f71-bf1f-c48b62fa6791

-- complete 时间
# pgo show workflow 51c9c73c-85dd-4f71-bf1f-c48b62fa6791 -n pgouser1
parameter           value
---------           -----
pg-cluster          antdb
task completed      2020-03-12T04:45:27Z
task submitted      2020-03-12T04:44:57Z
workflowid          51c9c73c-85dd-4f71-bf1f-c48b62fa6791

-- AntDB集群状态(master 已处于running)
# kubectl get pod -n pgouser1
NAME                                          READY   STATUS      RESTARTS   AGE
antdb-backrest-shared-repo-6cfbc4f764-fv57d   1/1     Running     0          101s
antdb-d8f8699-5tbgs                           1/1     Running     0          100s
antdb-stanza-create-mv22x                     0/1     Completed   0          78s
backrest-backup-antdb-9m5qt                   1/1     Running     0          74s

-- 过几秒钟再观察slave状态( 2个slave 也处于running)
# kubectl get pod -n pgouser1
NAME                                          READY   STATUS      RESTARTS   AGE
antdb-backrest-shared-repo-6cfbc4f764-fv57d   1/1     Running     0          3m11s
antdb-d8f8699-5tbgs                           1/1     Running     0          3m10s
antdb-ltnc-6dfb8c4647-9hhd7                   0/1     Running     0          82s
antdb-stanza-create-mv22x                     0/1     Completed   0          2m48s
antdb-tblw-d969f7cff-5gxpg                    0/1     Running     0          78s
backrest-backup-antdb-9m5qt                   0/1     Completed   0          2m44s

-- 查看AntDB 集群当前状态
# pgo show cluster antdb -n pgouser1

cluster : antdb (antdb-ha:4.0)
        pod : antdb-d8f8699-5tbgs (Running) on centos76-2 (1/1) (primary)
        pvc : antdb
        pod : antdb-ltnc-6dfb8c4647-9hhd7 (Running) on centos76-2 (1/1) (replica)
        pvc : antdb-ltnc
        pod : antdb-tblw-d969f7cff-5gxpg (Running) on centos76-2 (1/1) (replica)
        pvc : antdb-tblw
        resources : CPU Limit= Memory Limit=, CPU Request= Memory Request=
        storage : Primary=1G Replica=1G
        deployment : antdb
        deployment : antdb-backrest-shared-repo
        deployment : antdb-ltnc
        deployment : antdb-tblw
        service : antdb - ClusterIP (10.109.68.125)
        service : antdb-replica - ClusterIP (10.106.177.184)
        pgreplica : antdb-ltnc
        pgreplica : antdb-tblw
        labels : name=antdb pg-pod-anti-affinity= pgo-backrest=true autofail=true crunchy-pgbadger=false crunchy-pgha-scope=antdb pgo-version=4.2.1 crunchy_collect=false deployment-name=antdb pg-cluster=antdb workflowid=51c9c73c-85dd-4f71-bf1f-c48b62fa6791 archive-timeout=60 current-primary=antdb pgouser=someuser 

**注：该命令返回下述信息**

* AntDB的镜像信息
* 主从节点IP分布信息
* 主从节点各自的ClusterIP信息
* 容器的系统资源分配信息
* 数据库初始化时的参数信息

环境准备完毕，下面进行功能测试。
```

## 1. master 节点clone
Clone makes a copy of an existing PostgreSQL cluster managed by the Operator and creates a new PostgreSQL cluster managed by the Operator, with the data from the old cluster.

```
# pgo clone antdb newantdb -n pgouser1
Created clone task for:  newantdb
workflow id is  2cec9b6f-e716-44f8-af17-799a0fe79f42

# kubectl get pod -n pgouser1
NAME                                            READY   STATUS      RESTARTS   AGE
antdb-backrest-shared-repo-6cfbc4f764-fv57d     1/1     Running     0          29m
antdb-d8f8699-5tbgs                             1/1     Running     0          29m
antdb-ltnc-6dfb8c4647-9hhd7                     1/1     Running     0          27m
antdb-stanza-create-mv22x                       0/1     Completed   0          28m
antdb-tblw-d969f7cff-5gxpg                      1/1     Running     0          27m
backrest-backup-antdb-9m5qt                     0/1     Completed   0          28m
backrest-backup-newantdb-78j97                  0/1     Completed   0          15m
newantdb-66d9d47cdb-vsgsd                       1/1     Running     0          16m
newantdb-backrest-shared-repo-7b4f878f6-g9n8p   1/1     Running     0          16m
newantdb-stanza-create-4njjs                    0/1     Completed   0          15m
pgo-backrest-repo-sync-newantdb-iwfx-49rr6      0/1     Completed   0          17m
restore-newantdb-vjsg-p2s8s                     0/1     Completed   0          16m

# pgo show cluster newantdb -n pgouser1

cluster : newantdb (antdb-ha:4.0)
        pod : newantdb-66d9d47cdb-vsgsd (Running) on centos76-2 (1/1) (primary)
        pvc : newantdb
        pod : pgo-backrest-repo-sync-newantdb-iwfx-49rr6 (Succeeded) on centos76-2 (0/1) (unknown)
        pvc : newantdb-pgbr-repo
        resources : CPU Limit= Memory Limit=, CPU Request= Memory Request=
        storage : Primary=1G Replica=1G
        deployment : newantdb
        deployment : newantdb-backrest-shared-repo
        service : newantdb - ClusterIP (10.99.219.198)
        labels : crunchy-pgha-scope=newantdb deployment-name=newantdb name=newantdb pgo-version=4.2.1 pgouser=someuser workflowid=2cec9b6f-e716-44f8-af17-799a0fe79f42 autofail=true backrest-storage-type= pgo-backrest=true vendor=crunchydata current-primary=newantdb pg-cluster=newantdb 

```

## 2. slave 节点扩大/缩小节点数
allows you to adjust a Cluster's replica configuration.
### 2.1 扩大节点数
-- 当前节点信息 1主2从 架构
```
# pgo show cluster antdb -n pgouser1

cluster : antdb (antdb-ha:4.0)
        pod : antdb-d8f8699-5tbgs (Running) on centos76-2 (1/1) (primary)
        pvc : antdb
        pod : antdb-ltnc-6dfb8c4647-9hhd7 (Running) on centos76-2 (1/1) (replica)
        pvc : antdb-ltnc
        pod : antdb-tblw-d969f7cff-5gxpg (Running) on centos76-2 (1/1) (replica)
        pvc : antdb-tblw
```

-- 扩大1个节点，调整为1主3从架构
```
# pgo scale antdb --replica-count=1 -n pgouser1
WARNING: Are you sure? (yes/no): yes
created Pgreplica antdb-lprc

# pgo show cluster antdb -n pgouser1

cluster : antdb (antdb-ha:4.0)
        pod : antdb-d8f8699-5tbgs (Running) on centos76-2 (1/1) (primary)
        pvc : antdb
        pod : antdb-lprc-7555bb647-gqb2c (Running) on centos76-2 (1/1) (replica)
        pvc : antdb-lprc
        pod : antdb-ltnc-6dfb8c4647-9hhd7 (Running) on centos76-2 (1/1) (replica)
        pvc : antdb-ltnc
        pod : antdb-tblw-d969f7cff-5gxpg (Running) on centos76-2 (1/1) (replica)
        pvc : antdb-tblw

# kubectl get pod -n pgouser1
NAME                                          READY   STATUS      RESTARTS   AGE
antdb-backrest-shared-repo-6cfbc4f764-fv57d   1/1     Running     0          44m
antdb-d8f8699-5tbgs                           1/1     Running     0          44m
antdb-lprc-7555bb647-gqb2c                    1/1     Running     0          98s
antdb-ltnc-6dfb8c4647-9hhd7                   1/1     Running     0          42m
antdb-stanza-create-mv22x                     0/1     Completed   0          43m
antdb-tblw-d969f7cff-5gxpg                    1/1     Running     0          42m
backrest-backup-antdb-9m5qt                   0/1     Completed   0          43m

进入master节点的容器，确认信扩容的slave节点已添加成功
# docker exec -it 4907f4a88334 psql
psql (11.5)
Type "help" for help.

postgres=# select application_name,client_addr,backend_start,sync_state from pg_stat_replication ;
      application_name       | client_addr |         backend_start         | sync_state 
-----------------------------+-------------+-------------------------------+------------
 antdb-ltnc-6dfb8c4647-9hhd7 | 10.244.1.53 | 2020-03-12 04:48:12.057262+00 | async
 antdb-tblw-d969f7cff-5gxpg  | 10.244.1.54 | 2020-03-12 04:48:15.271258+00 | async
 antdb-lprc-7555bb647-gqb2c  | 10.244.1.71 | 2020-03-12 05:28:29.516958+00 | async
(3 rows)

postgres=# select version();
                                                           version                                                            
------------------------------------------------------------------------------------------------------------------------------
 PostgreSQL 11.5 ADB 4.1devel 461fafc on x86_64-pc-linux-gnu, compiled by gcc (GCC) 4.8.5 20150623 (Red Hat 4.8.5-36), 64-bit
(1 row)

```

### 2.2 缩小节点数
-- 当前节点信息 1主3从 架构
```
# pgo show cluster antdb -n pgouser1

cluster : antdb (antdb-ha:4.0)
        pod : antdb-d8f8699-5tbgs (Running) on centos76-2 (1/1) (primary)
        pvc : antdb
        pod : antdb-lprc-7555bb647-gqb2c (Running) on centos76-2 (1/1) (replica)
        pvc : antdb-lprc
        pod : antdb-ltnc-6dfb8c4647-9hhd7 (Running) on centos76-2 (1/1) (replica)
        pvc : antdb-ltnc
        pod : antdb-tblw-d969f7cff-5gxpg (Running) on centos76-2 (1/1) (replica)
        pvc : antdb-tblw

```

-- 缩小一个slave节点，调整为 1主2从 架构
```
# pgo scaledown antdb --query -n pgouser1

Cluster: antdb
REPLICA                 STATUS          NODE            REPLICATION LAG
                        running                                    0 MB
antdb-ltnc              running         centos76-2                 0 MB
                        running                                    0 MB

# pgo scaledown antdb --target=antdb-tblw -n pgouser1
WARNING: Are you sure? (yes/no): yes
deleted Pgreplica antdb-tblw

指定的slave节点已从集群中剔除
# pgo show cluster antdb -n pgouser1

cluster : antdb (antdb-ha:4.0)
        pod : antdb-d8f8699-5tbgs (Running) on centos76-2 (1/1) (primary)
        pvc : antdb
        pod : antdb-lprc-7555bb647-gqb2c (Running) on centos76-2 (1/1) (replica)
        pvc : antdb-lprc
        pod : antdb-ltnc-6dfb8c4647-9hhd7 (Running) on centos76-2 (1/1) (replica)
        pvc : antdb-ltnc

# kubectl get pod -n pgouser1
NAME                                          READY   STATUS    RESTARTS   AGE
antdb-backrest-shared-repo-6cfbc4f764-fv57d   1/1     Running   0          53m
antdb-d8f8699-5tbgs                           1/1     Running   0          53m
antdb-lprc-7555bb647-gqb2c                    1/1     Running   0          11m
antdb-ltnc-6dfb8c4647-9hhd7                   1/1     Running   0          51m

进入master节点的容器，确认信扩容的slave节点已添加成功
# docker exec -it 4907f4a88334 psql
psql (11.5)
Type "help" for help.

postgres=# select application_name,client_addr,backend_start,sync_state from pg_stat_replication ;
      application_name       | client_addr |         backend_start         | sync_state 
-----------------------------+-------------+-------------------------------+------------
 antdb-ltnc-6dfb8c4647-9hhd7 | 10.244.1.53 | 2020-03-12 04:48:12.057262+00 | async
 antdb-lprc-7555bb647-gqb2c  | 10.244.1.71 | 2020-03-12 05:28:29.516958+00 | async
(2 rows)
```

## 3. 集群 failover
Performs a manual failover.
```
-- 当前状态，pod antdb-d8f8699-5tbgs 为master节点
# pgo show cluster antdb -n pgouser1

cluster : antdb (antdb-ha:4.0)
        pod : antdb-d8f8699-5tbgs (Running) on centos76-2 (1/1) (primary)
        pvc : antdb
        pod : antdb-lprc-7555bb647-gqb2c (Running) on centos76-2 (1/1) (replica)
        pvc : antdb-lprc
        pod : antdb-ltnc-6dfb8c4647-9hhd7 (Running) on centos76-2 (1/1) (replica)
        pvc : antdb-ltnc

-- 手工执行failover
# pgo failover antdb -n pgouser1 --target=antdb-ltnc
WARNING: Are you sure? (yes/no): yes
created Pgtask (failover) for cluster antdb

--重新查看集群状态，指定的pod antdb-ltnc已提升为master，old master作为slave加入集群
# pgo show cluster antdb -n pgouser1

cluster : antdb (antdb-ha:4.0)
        pod : antdb-d8f8699-5tbgs (Running) on centos76-2 (1/1) (replica)
        pvc : antdb
        pod : antdb-lprc-7555bb647-gqb2c (Running) on centos76-2 (1/1) (replica)
        pvc : antdb-lprc
        pod : antdb-ltnc-6dfb8c4647-9hhd7 (Running) on centos76-2 (1/1) (primary)
        pvc : antdb-ltnc

--进入master节点的容器，确认failover执行成功
# docker exec -it 4907f4a88334 psql
psql (11.5)
Type "help" for help.

postgres=# select pg_is_in_recovery();
 pg_is_in_recovery 
-------------------
 f
(1 row)

postgres=# select application_name,client_addr,backend_start,sync_state from pg_stat_replication ;
      application_name      | client_addr |         backend_start         | sync_state 
----------------------------+-------------+-------------------------------+------------
 antdb-d8f8699-5tbgs        | 10.244.1.50 | 2020-03-12 05:45:34.662937+00 | async
 antdb-lprc-7555bb647-gqb2c | 10.244.1.71 | 2020-03-12 05:45:40.648821+00 | async
(2 rows)

postgres=# select version();
                                                           version                                                            
------------------------------------------------------------------------------------------------------------------------------
 PostgreSQL 11.5 ADB 4.1devel 461fafc on x86_64-pc-linux-gnu, compiled by gcc (GCC) 4.8.5 20150623 (Red Hat 4.8.5-36), 64-bit
(1 row)
```

## 4. 数据库 backup/restore
Performs a backup/restore
### 4.1 数据库backup
```
登录数据库，在不同时间点插入几条数据
# docker exec -it 081df9353f74  psql
psql (11.5)
Type "help" for help.

postgres=# select now();
              now              
-------------------------------
 2020-03-12 05:50:43.950652+00
(1 row)

postgres=# create table sy01(id int);
CREATE TABLE
postgres=# insert into sy01 values (1);
INSERT 0 1
postgres=# select now();               
              now              
-------------------------------
 2020-03-12 05:51:16.775475+00
(1 row)

postgres=# select now();
              now              
-------------------------------
 2020-03-12 05:51:24.576438+00
(1 row)

postgres=# insert into sy01 values (2);
INSERT 0 1
postgres=# select now();               
              now              
-------------------------------
 2020-03-12 05:51:34.172965+00
(1 row)

执行数据库备份
# pgo backup antdb -n pgouser1
created Pgtask backrest-backup-antdb

后台实际调用的命令
pgbackrest backup --type=full

备份任务成功执行，耗时 15s
# kubectl get job -n pgouser1
NAME                    COMPLETIONS   DURATION   AGE
backrest-backup-antdb   1/1           15s        31s

显示数据库备份的明细
# pgo show backup antdb -n pgouser1

backrest : antdb

Storage Type: local
stanza: db
    status: ok
    cipher: none

    db (current)
        wal archive min/max (11-1): 000000010000000000000001/00000002000000000000000B

        full backup: 20200312-044533F
            timestamp start/stop: 2020-03-12 04:45:33 / 2020-03-12 04:46:48
            wal start/stop: 000000010000000000000002 / 000000010000000000000003
            database size: 30.6MB, backup size: 30.6MB
            repository size: 3.7MB, repository backup size: 3.7MB

        incr backup: 20200312-044533F_20200312-055155I
            timestamp start/stop: 2020-03-12 05:51:55 / 2020-03-12 05:52:05
            wal start/stop: 00000002000000000000000A / 00000002000000000000000A
            database size: 30.6MB, backup size: 3.0MB
            repository size: 3.7MB, repository backup size: 327.8KB
            backup reference list: 20200312-044533F
```

### 4.2 数据库restore
```
# pgo restore antdb -n pgouser1 --pitr-target='2020-03-12 08:24:51.53954+00' --backup-opts='--type=time'
Warning:  If currently running, the primary database in this cluster will be stopped and recreated as part of this workflow!
WARNING: Are you sure? (yes/no): yes
restore performed on antdb to antdb-febu opts=--type=time pitr-target=2020-03-12 08:24:51.53954+00

后台实际调用的命令
pgbackrest restore --type=time '--target=2020-03-12 08:24:51.53954+00'

当前集群状态，所有antdb集群的pod被重建
# kubectl get pod -n pgouser1
NAME                                                  READY   STATUS              RESTARTS   AGE
antdb-5fb8d7898d-98lv4                                1/1     Running             0          42m
antdb-backrest-shared-repo-6cfbc4f764-j2m6j           1/1     Running             0          42m
antdb-ksaq-79d55bc7cf-gxzqd                           1/1     Running             0          3m17s
antdb-stanza-create-gsfsg                             0/1     Completed           0          41m
antdb-wtlp-64c665cc74-qm9wz                           1/1     Running             0          3m14s
backrest-backup-antdb-lngck                           0/1     Completed           0          41m

# pgo show cluster antdb -n pgouser1

cluster : antdb (antdb-ha:4.0)
        pod : antdb-5fb8d7898d-98lv4 (Running) on centos76-2 (1/1) (primary)
        pvc : antdb
        pod : antdb-ksaq-79d55bc7cf-gxzqd (Running) on centos76-2 (1/1) (replica)
        pvc : antdb-ksaq
        pod : antdb-wtlp-64c665cc74-qm9wz (Running) on centos76-2 (1/1) (replica)
        pvc : antdb-wtlp

登录数据库，查看是否已恢复到指定时间点
postgres=# select version();
                                                           version                                                            
------------------------------------------------------------------------------------------------------------------------------
 PostgreSQL 11.5 ADB 4.1devel 461fafc on x86_64-pc-linux-gnu, compiled by gcc (GCC) 4.8.5 20150623 (Red Hat 4.8.5-36), 64-bit
(1 row)

postgres=# table sy01;
 id 
----
  1
  2
(2 rows)

**注：此处pgbackrest工具将其恢复到最新了，未按命令中指定时间点恢复。已记录该问题，原因尚不能定位。**

```

## 5. 数据库 版本升级
Performs an upgrade on a PostgreSQL cluster.

This upgrade will update the CCPImageTag of the deployment for the primary and all replicas.

The running containers are upgraded one at a time, sequentially, in the following order: replicas, backrest-repo, then primary.

准备将镜像从antdb-ha:4.0 升级至 antdb-ha:6.0。

其中：

antdb-ha:4.0 是使用4.1devel 461fafc的git commit号制作的镜像

antdb-ha:6.0 是使用4.1devel d5cbd85的git commit号制作的镜像

```
-- 执行版本升级
# pgo upgrade antdb -n pgouser1 --ccp-image-tag=6.0 -n pgouser1

created minor upgrade task for antdb

-- 升级期间集群的状态
(串行方式升级，升级顺序为replicas, backrest-repo, then primary；升级时，对应实例处于停机状态，其他实例正常运行)
# pgo test antdb -n pgouser1

cluster : antdb
        Services
                primary (10.98.242.2:5432): UP
                replica (10.107.147.96:5432): UP
        Instances
                unknown (antdb-5ccc777946-kcm2n): DOWN
                unknown (antdb-5fb8d7898d-98lv4): DOWN
                unknown (antdb-ksaq-7c6f55dc45-5kc76): UP
                primary (antdb-wtlp-646f66fb8d-lwk9z): UP

-- 最终状态
# pgo test antdb -n pgouser1

cluster : antdb
        Services
                primary (10.98.242.2:5432): UP
                replica (10.107.147.96:5432): UP
        Instances
                replica (antdb-5ccc777946-kcm2n): UP
                replica (antdb-ksaq-7c6f55dc45-5kc76): UP
                primary (antdb-wtlp-646f66fb8d-lwk9z): UP

登录数据库，检查版本号
# docker exec -it 2b24c58e9370 psql
psql (11.5)
Type "help" for help.

postgres=# select version();
                                                           version                                                            
------------------------------------------------------------------------------------------------------------------------------
 PostgreSQL 11.5 ADB 4.1devel d5cbd85 on x86_64-pc-linux-gnu, compiled by gcc (GCC) 4.8.5 20150623 (Red Hat 4.8.5-36), 64-bit
(1 row)

postgres=# table sy01;
 id 
----
  1
  2
(2 rows)

```

## 6. initdb时，数据库参数可指定配置

默认的configmap 名称是xxxx-pgha-default-config。其中xxxx指 pgo create cluster 时指定的集群名称。

创建定制化configmap 名称是pgo-custom-pg-config。名称可随意调整。官方提供了shell脚本和配置文件的模板，可轻松实现定制化配置。 

```
-- 调整配置模板文件中的参数配置
# cd $PGOROOT/examples/custom-config
按需调整postgresql.conf对应的配置项
# vim postgres-ha.yaml
---
bootstrap:
  dcs:
    postgresql:
      parameters:
        logging_collector: on
        log_directory: pglogs
        log_min_duration_statement: 0
        log_statement: all
        max_wal_senders: 6
        shared_preload_libraries: pgaudit.so,pg_stat_statements.so
        log_directory: pg_log
        log_destination: csvlog
        logging_collector: on
        log_min_messages: info
postgresql:
  pg_hba:
    - local all postgres peer
    - local all crunchyadm peer
    - host replication primaryuser 0.0.0.0/0 md5
    - host all primaryuser 0.0.0.0/0 reject
    - host all postgres 0.0.0.0/0 md5
    - host all testuser1 0.0.0.0/0 md5
    - host all testuser2 0.0.0.0/0 md5

在初始化数据库时，按需执行对应sql，完成数据库环境的初始化。(如创建自己的数据库、用户名、密码和插件等)
# vim setup.sql 
--- System Setup
SET application_name="container_setup";

CREATE EXTENSION IF NOT EXISTS pgaudit;
--- add
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

CREATE USER PGHA_USER LOGIN;
ALTER USER PGHA_USER PASSWORD 'PGHA_USER_PASSWORD';

CREATE DATABASE PGHA_DATABASE;
GRANT ALL PRIVILEGES ON DATABASE PGHA_DATABASE TO PGHA_USER;

CREATE USER testuser2 LOGIN;
ALTER USER testuser2 PASSWORD 'customconfpass';

CREATE DATABASE PGHA_DATABASE;
GRANT ALL PRIVILEGES ON DATABASE PGHA_DATABASE TO testuser2;

--- PGHA_DATABASE Setup

\c PGHA_DATABASE

CREATE EXTENSION IF NOT EXISTS pgaudit;
--- add 
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

CREATE SCHEMA IF NOT EXISTS PGHA_USER;

/* The following has been customized for the custom-config example */

SET SESSION AUTHORIZATION PGHA_USER;

CREATE TABLE custom_config_table (
        KEY VARCHAR(30) PRIMARY KEY,
        VALUE VARCHAR(50) NOT NULL,
        UPDATEDT TIMESTAMP NOT NULL
);

INSERT INTO custom_config_table (KEY, VALUE, UPDATEDT) VALUES ('CPU', '256', now());

GRANT ALL ON custom_config_table TO testuser2;

-- 执行脚本，创建configmap
# export PGO_NAMESPACE=pgouser1
# $PGOROOT/examples/custom-config/create.sh
Fri Mar 13 12:58:05 CST 2020 INFO: PGO_NAMESPACE=pgouser1
Error from server (NotFound): configmaps "pgo-custom-pg-config" not found
configmap/pgo-custom-pg-config created
# kubectl get configmap -n pgouser1
NAME                   DATA   AGE
pgo-custom-pg-config   4      37s

-- 使用定制化configmap创建AntDB集群
# pgo create cluster antdb  --ccp-image=antdb-ha --ccp-image-tag=4.0 --namespace=pgouser1 --replica-count=2 --custom-config=pgo-custom-pg-config
created Pgcluster antdb
workflow id 89488e2b-c6b8-4849-bc1d-d35fee33992e
# kubectl get pod -n pgouser1
NAME                                          READY   STATUS      RESTARTS   AGE
antdb-564765df76-sw665                        1/1     Running     0          36s
antdb-backrest-shared-repo-6cfbc4f764-fssv7   1/1     Running     0          36s
antdb-stanza-create-mjg69                     0/1     Completed   0          9s
backrest-backup-antdb-tzz4n                   1/1     Running     0          5s

-- 验证定制化配置是否生效(默认的configmap xxxx-pgha-default-config，没有打开pglog，一旦数据库出现问题，不方便定位问题)
# kubectl exec -it antdb-564765df76-sw665 psql -n pgouser1
psql (11.5)
Type "help" for help.

postgres=# show log_destination;
 log_destination 
-----------------
 csvlog
(1 row)

postgres=# show shared_preload_libraries ;
     shared_preload_libraries     
----------------------------------
 pgaudit.so,pg_stat_statements.so
(1 row)

postgres=# show log_min_messages ;
 log_min_messages 
------------------
 info
(1 row)

postgres=# select version();
                                                           version                                                            
------------------------------------------------------------------------------------------------------------------------------
 PostgreSQL 11.5 ADB 4.1devel 461fafc on x86_64-pc-linux-gnu, compiled by gcc (GCC) 4.8.5 20150623 (Red Hat 4.8.5-36), 64-bit
(1 row)

-- 展示configmap的完整信息
# kubectl get configmap pgo-custom-pg-config -o json -n pgouser1
{
    "apiVersion": "v1",
    "data": {
        "create.sh": "#!/bin/bash\n\n# Copyright 2018 Crunchy Data Solutions, Inc.\n# Licensed under the Apache License, Version 2.0 (the \"License\");\n# you may not use this file except in compliance with the License.\n# You may obtain a copy of the License at\n#\n# http://www.apache.org/licenses/LICENSE-2.0\n#\n# Unless required by applicable law or agreed to in writing, software\n# distributed under the License is distributed on an \"AS IS\" BASIS,\n# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.\n# See the License for the specific language governing permissions and\n# limitations under the License.\n\nRED=\"\\033[0;31m\"\nGREEN=\"\\033[0;32m\"\nRESET=\"\\033[0m\"\n\nfunction echo_err() {\n    echo -e \"${RED?}$(date) ERROR: ${1?}${RESET?}\"\n}\n\nfunction echo_info() {\n    echo -e \"${GREEN?}$(date) INFO: ${1?}${RESET?}\"\n}\n\n\nDIR=\"$( cd \"$( dirname \"${BASH_SOURCE[0]}\" )\" \u0026\u0026 pwd )\"\n\n#Error if PGO_CMD not set\nif [[ -z ${PGO_CMD} ]]\nthen\n\techo_err \"PGO_CMD is not set.\"\nfi\n\n#Error is PGO_NAMESPACE not set\nif [[ -z ${PGO_NAMESPACE} ]]\nthen\n        echo_err \"PGO_NAMESPACE is not set.\"\nfi\n\n# If both PGO_CMD and PGO_NAMESPACE are set, config map can be created.\nif [[ ! -z ${PGO_CMD} ]] \u0026\u0026 [[ ! -z ${PGO_NAMESPACE} ]]\nthen\n\n\techo_info \"PGO_NAMESPACE=${PGO_NAMESPACE}\"\n\t\n\t$PGO_CMD delete configmap pgo-custom-pg-config -n ${PGO_NAMESPACE}\n\n\t$PGO_CMD create configmap pgo-custom-pg-config --from-file=$DIR -n ${PGO_NAMESPACE}\nfi\n",
        "postgres-ha.yaml": "---\nbootstrap:\n  dcs:\n    postgresql:\n      parameters:\n        logging_collector: on\n        log_directory: pglogs\n        log_min_duration_statement: 0\n        log_statement: all\n        max_wal_senders: 6\n        shared_preload_libraries: pgaudit.so,pg_stat_statements.so\n        log_directory: pg_log\n        log_destination: csvlog\n        logging_collector: on\n        log_min_messages: info\npostgresql:  \n  pg_hba:\n    - local all postgres peer\n    - local all crunchyadm peer\n    - host replication primaryuser 0.0.0.0/0 md5\n    - host all primaryuser 0.0.0.0/0 reject\n    - host all postgres 0.0.0.0/0 md5\n    - host all testuser1 0.0.0.0/0 md5\n    - host all testuser2 0.0.0.0/0 md5\n",
        "postgresql.conf": "shared_buffers = 256MB\ntemp_buffers = 10MB\nwork_mem = 5MB\nshared_preload_libraries = 'pg_stat_statements.so'\n",
        "setup.sql": "--- System Setup\nSET application_name=\"container_setup\";\n\nCREATE EXTENSION IF NOT EXISTS pgaudit;\n--- add\nCREATE EXTENSION IF NOT EXISTS pg_stat_statements;\n\nCREATE USER PGHA_USER LOGIN;\nALTER USER PGHA_USER PASSWORD 'PGHA_USER_PASSWORD';\n\nCREATE DATABASE PGHA_DATABASE;\nGRANT ALL PRIVILEGES ON DATABASE PGHA_DATABASE TO PGHA_USER;\n\nCREATE USER testuser2 LOGIN;\nALTER USER testuser2 PASSWORD 'customconfpass';\n\nCREATE DATABASE PGHA_DATABASE;\nGRANT ALL PRIVILEGES ON DATABASE PGHA_DATABASE TO testuser2;\n\n--- PGHA_DATABASE Setup\n\n\\c PGHA_DATABASE\n\nCREATE EXTENSION IF NOT EXISTS pgaudit;\n--- add \nCREATE EXTENSION IF NOT EXISTS pg_stat_statements;\n\nCREATE SCHEMA IF NOT EXISTS PGHA_USER;\n\n/* The following has been customized for the custom-config example */\n\nSET SESSION AUTHORIZATION PGHA_USER;\n\nCREATE TABLE custom_config_table (\n\tKEY VARCHAR(30) PRIMARY KEY,\n\tVALUE VARCHAR(50) NOT NULL,\n\tUPDATEDT TIMESTAMP NOT NULL\n);\n\nINSERT INTO custom_config_table (KEY, VALUE, UPDATEDT) VALUES ('CPU', '256', now());\n\nGRANT ALL ON custom_config_table TO testuser2;\n"
    },
    "kind": "ConfigMap",
    "metadata": {
        "creationTimestamp": "2020-03-13T04:58:07Z",
        "name": "pgo-custom-pg-config",
        "namespace": "pgouser1",
        "resourceVersion": "1601888",
        "selfLink": "/api/v1/namespaces/pgouser1/configmaps/pgo-custom-pg-config",
        "uid": "e982413c-550d-4caa-8965-02eb663bab8c"
    }
}
```

## 7. 集群自动failover
antdb-ha的镜像，不仅打包了antdb的版本，也打包了patroni。

软件层面的流复制和HA高可用，也是由patroni软件实现的(patroni版本号 1.6.3)。
```
--当前集群架构
# pgo show cluster antdb -n pgouser1

cluster : antdb (antdb-ha:4.0)
        pod : antdb-564765df76-sw665 (Running) on centos76-2 (1/1) (primary)
        pvc : antdb
        pod : antdb-aaek-58db7587c6-45zs5 (Running) on centos76-2 (1/1) (replica)
        pvc : antdb-aaek
        pod : antdb-oqja-7c66fb59d5-pfw8l (Running) on centos76-2 (1/1) (replica)
        pvc : antdb-oqja

# pgo test antdb -n pgouser1

cluster : antdb
        Services
                primary (10.109.240.122:5432): UP
                replica (10.108.194.230:5432): UP
        Instances
                primary (antdb-564765df76-sw665): UP
                replica (antdb-aaek-58db7587c6-45zs5): UP
                replica (antdb-oqja-7c66fb59d5-pfw8l): UP

--模拟master节点故障(删除master节点的数据目录)
# cd /data/pgo/odev/pv
# rm -Rf antdb/*

--slave节点antdb-oqja已经接管业务，old master 显示为down状态
# pgo test antdb -n pgouser1

cluster : antdb
        Services
                primary (10.109.240.122:5432): UP
                replica (10.108.194.230:5432): UP
        Instances
                unknown (antdb-564765df76-sw665): DOWN
                replica (antdb-aaek-58db7587c6-45zs5): UP
                primary (antdb-oqja-7c66fb59d5-pfw8l): UP

--old master以slave角色重新加入集群
# pgo test antdb -n pgouser1

cluster : antdb
        Services
                primary (10.109.240.122:5432): UP
                replica (10.108.194.230:5432): UP
        Instances
                replica (antdb-564765df76-sw665): UP
                replica (antdb-aaek-58db7587c6-45zs5): UP
                primary (antdb-oqja-7c66fb59d5-pfw8l): UP

# pgo show cluster antdb -n pgouser1

cluster : antdb (antdb-ha:4.0)
        pod : antdb-564765df76-sw665 (Running) on centos76-2 (1/1) (replica)
        pvc : antdb
        pod : antdb-aaek-58db7587c6-45zs5 (Running) on centos76-2 (1/1) (replica)
        pvc : antdb-aaek
        pod : antdb-oqja-7c66fb59d5-pfw8l (Running) on centos76-2 (1/1) (primary)
        pvc : antdb-oqja
```

# 遇到的问题
## 1. clone操作，新的集群只克隆了master节点，slave节点全都没克隆过来。

**问题现象**
```
-- 查看clone操作时的workflow信息
# pgo show workflow 2cec9b6f-e716-44f8-af17-799a0fe79f42 -n pgouser1
parameter           value
---------           -----
workflowid          2cec9b6f-e716-44f8-af17-799a0fe79f42
clone 1.1: create pvc2020-03-12T04:56:49Z
clone 1.2: sync pgbackrest repo2020-03-12T04:56:55Z
clone 2: restoring backup2020-03-12T04:57:04Z
clone 3: cluster creating2020-03-12T04:57:53Z
pg-cluster          newantdb
task submitted      2020-03-12T04:56:49Z

只有submit时间，一直不反馈 complete 时间。状态一直显示 cluster creating 集群创建中的状态。
```

**错误原因** 尚未定位

**解决方式** 

尚未找到解决方案。 

## 2. 按指定时间点restore后，未恢复到指定时间点，总是恢复到最新时间点

**问题现象**

```
执行下述命令后，数据库总是被恢复到最新时间点
pgo restore antdb -n pgouser1 --pitr-target='2020-03-12 08:24:51.53954+00' --backup-opts='--type=time'
```

**错误原因** 尚未定位

**解决方式** 

尚未找到解决方案。

# 总结
AntDB 单机版镜像已部署成功，后续在使用/ha切换/operator和其他一些方面，仍需测试验证。

另外，一些专用术语(如镜像前缀crunchydata如何调整等)、数据库参数调整、配套工具等，仍需进一步研究，使其更接近于AntDB的品性。

# 参考
AntDB QQ群号：496464280

[AntDB github链接](https://github.com/ADBSQL)