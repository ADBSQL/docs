# postgresql 基于k8s的operator有状态部署
***
本文主要探讨postgresql基于k8s通过operator实现有状态部署的实施方案。
通过本文实现下述功能：
* operator 部署
* postgresql 部署
* postgresql 服务访问
* 验证过程中的问题分析处理

***

# 版本说明
|postgres-operator 服务端版本|4.2.1|https://github.com/CrunchyData/postgres-operator/tree/v4.2.1|
|:-----|:-------|:-------|
|postgres-operator 客户端版本(pgo)|4.2.1|https://github.com/CrunchyData/postgres-operator/releases/download/v4.2.1/postgres-operator.4.2.1.tar.gz|
|kubernetes 版本|1.13+||
|docker 版本|18.09.8||
|go 版本|1.13.7|https://dl.google.com/go/go1.13.7.linux-amd64.tar.gz|
|expenv 版本|1.2.0|https://github.com/blang/expenv，expenv已在pgo客户端版本集成，但不用单独安装，直接安装pgo即可|
|postgresql 版本|11.6||
|容器内os 版本|centos7||

# postgres-operator 支持的Kuberentes storage类型

* HostPath
* NFS
* StorageOS
* Rook
* Google Compute Engine persistent volumes

and more.

# 需要准备的镜像
**operator相关镜像：**

$PGOROOT/bin/pull-from-gcr.sh，修改下述2个配置后，执行该脚本自动拉取镜像
1. 修改脚本的仓库地址，将原'us.gcr.io/container-suite'修改为'crunchydata'
2. 修改镜像的版本号 $PGO_IMAGE_TAG，最新的是 centos7-4.3.0 ，此处我们调整为 centos7-4.2.1

镜像文件较大，需耐心等待 1 小时左右，包括下列镜像

* pgo-event
* pgo-backrest-repo
* pgo-backrest-restore
* pgo-scheduler
* pgo-sqlrunner
* postgres-operator
* pgo-apiserver
* pgo-rmdata
* pgo-backrest
* pgo-load
* pgo-client

**postgresql相关镜像：**

$PGOROOT/bin/pull-ccp-from-gcr.sh，修改下述2个配置后，执行该脚本自动拉取镜像

1. 修改脚本的仓库地址，将原'us.gcr.io/container-suite'修改为'crunchydata'
2. 修改镜像的版本号 $CCP_IMAGE_TAG，最新的是 centos7-12.1-4.3.0 ，此处我们调整为 centos7-11.6-4.2.1

镜像文件较大，需耐心等待 1 小时左右，包括下列镜像
* crunchy-postgres
* crunchy-backup
* crunchy-collect
* crunchy-pgbadger
* crunchy-pgbouncer
* crunchy-pgbasebackup-restore
* crunchy-pgdump
* crunchy-pgrestore

**另外，需单独手工拉取一个 postgres-ha 的高可用镜像，命令如下：**
```
docker pull crunchydata/crunchy-postgres-ha:centos7-11.6-4.2.1
```

**其他工具类相关镜像：**

执行脚本 $PGOROOT/bin/pre-pull-crunchy-containers.sh

# 端口规划
##  容器端口
|容器|端口|配置文件路径|
|:-----|:-------|:----|
|API Server|8443|$HOME/.bashrc|
|nsqadmin|4151|$PGOROOT/deploy/deployment.json 和 $PGOROOT/deploy/service.json|
|nsqd|4150|$PGOROOT/deploy/deployment.json 和 $PGOROOT/deploy/service.json|

其中:

$PGOROOT指postgres-operator服务端版本解压后的根目录，如/data/pgo/odev/src/github.com/crunchydata/postgres-operator-4.2.1;

$HOME/.bashrc文件可从$PGOROOT/examples/envs.sh文件拷贝追加进去

## 服务端口
|服务|端口|配置文件路径|
|:-----|:-------|:----|
|postgresql|5432|$PGOROOT/conf/postgres-operator/pgo.yaml|
|pgbouncer|5432|$PGOROOT/conf/postgres-operator/pgo.yaml|
|pgbackrest|2022|$PGOROOT/conf/postgres-operator/pgo.yaml|
|postgres-exporter|9187|$PGOROOT/conf/postgres-operator/pgo.yaml|

## 应用端口
|应用|端口|配置文件路径|
|:-----|:-------|:----|
|pgbadger|10000|$PGOROOT/conf/postgres-operator/pgo.yaml|

# 安装部署
## 1. 新建安装目录，并上传postgres-operator服务端版本
```
--k8s集群所有主机都需要创建目录
export GOPATH=/data/pgo/odev
mkdir -p $GOPATH/odev/src/github.com/crunchydata $GOPATH/odev/bin $GOPATH/odev/pkg $GOPATH/odev/pv

--以下步骤只在某台机器执行即可
cd $GOPATH/odev/src/github.com/crunchydata

将下载的 postgres-operator-4.2.1.zip 版本上传至该路径，并解压。

解压后安装目录结构如下：

# pwd
/data/pgo/odev/src/github.com/crunchydata
# ll
total 36448
drwxr-x--- 35 root root     4096 Feb 19 09:46 postgres-operator-4.2.1
-rw-r-----  1 root root 37317064 Feb 18 10:42 postgres-operator-4.2.1.zip
# ll /data/pgo/odev/
total 16
drwxr-xr-x 5 root root 4096 Feb 18 10:41 bin
drwxr-x--- 2 root root 4096 Feb 11 12:01 pkg
drwxr-x--- 2 root root 4096 Feb 11 16:28 pv
drwxr-x--- 3 root root 4096 Feb 11 12:01 src
# ll postgres-operator-4.2.1
total 396
drwxr-x---  3 root root   4096 Jan 17 00:12 ansible
drwxr-x---  3 root root   4096 Jan 17 00:12 apis
drwxr-x--- 30 root root   4096 Jan 17 00:12 apiserver
-rw-r-----  1 root root   5510 Jan 17 00:12 apiserver.go
drwxr-x---  2 root root   4096 Jan 17 00:12 apiservermsgs
drwxr-x--- 12 root root   4096 Jan 17 00:12 bin
-rw-r-----  1 root root   5159 Jan 17 00:12 btn.png
drwxr-x---  2 root root   4096 Jan 17 00:12 centos7
drwxr-x---  5 root root   4096 Jan 17 00:12 conf
drwxr-x---  2 root root   4096 Jan 17 00:12 config
-rw-r-----  1 root root   9156 Jan 17 00:12 CONTRIBUTING.md
drwxr-x---  2 root root   4096 Jan 17 00:12 controller
-rw-r-----  1 root root 169205 Jan 17 00:12 crunchy_logo.png
drwxr-x---  2 root root   4096 Jan 17 00:12 deploy
drwxr-x---  2 root root   4096 Jan 17 00:12 events
drwxr-x---  8 root root   4096 Jan 17 00:12 examples
-rw-r-----  1 root root  20185 Jan 17 00:12 Gopkg.lock
-rw-r-----  1 root root    506 Jan 17 00:12 Gopkg.toml
drwxr-x---  6 root root   4096 Jan 17 00:12 hugo
drwxr-x---  4 root root   4096 Jan 17 00:12 installers
-rw-r-----  1 root root    801 Jan 17 00:12 ISSUE_TEMPLATE.md
drwxr-x---  2 root root   4096 Jan 17 00:12 kubeapi
-rw-r-----  1 root root  10784 Jan 17 00:12 LICENSE.md
drwxr-x---  6 root root   4096 Jan 17 00:12 licenses
drwxr-x---  2 root root   4096 Jan 17 00:12 logging
-rw-r-----  1 root root   4825 Jan 17 00:12 Makefile
drwxr-x---  2 root root   4096 Jan 17 00:12 ns
drwxr-x--- 10 root root   4096 Jan 17 00:12 operator
drwxr-x---  5 root root   4096 Jan 17 00:12 pgo
drwxr-x---  2 root root   4096 Jan 17 00:12 pgo-backrest
drwxr-x---  3 root root   4096 Jan 17 00:12 pgo-rmdata
drwxr-x---  3 root root   4096 Jan 17 00:12 pgo-scheduler
-rw-r-----  1 root root   6206 Jan 17 00:12 postgres-operator.go
-rw-r-----  1 root root    907 Jan 17 00:12 PULL_REQUEST_TEMPLATE.md
drwxr-x---  2 root root   4096 Jan 17 00:12 pv
-rw-r-----  1 root root  10698 Jan 17 00:12 README.md
drwxr-x---  4 root root   4096 Jan 17 00:12 redhat
drwxr-x---  2 root root   4096 Jan 17 00:12 rhel7
drwxr-x---  2 root root   4096 Jan 17 00:12 sshutil
drwxr-x---  4 root root   4096 Jan 17 00:12 testing
drwxr-x---  2 root root   4096 Jan 17 00:12 tlsutil
drwxr-x---  2 root root   4096 Jan 17 00:12 ubi7
drwxr-x---  2 root root   4096 Jan 17 00:12 util
drwxr-x---  8 root root   4096 Jan 17 00:12 vendor
 
```

## 2. 配置环境变量 $HOME/.bashrc
1. $HOME/.bashrc文件可从$PGOROOT/examples/envs.sh文件拷贝追加进去

(_**注意，是追加到原 $HOME/.bashrc 文件里**_)

2. envs.sh的环境变量说明

|环境变量|默认值|描述|
|:-----|:-------|:----|
|GOPATH|/data/pgo/odev|$PGOROOT/conf/postgres-operator/pgo.yaml|

参考官方链接 https://access.crunchydata.com/documentation/postgres-operator/4.2.1/installation/common-env/

## 3. 调整配置
1. $PGOROOT/conf/postgres-operator/pgo.yaml

```
CCPImageTag:  centos7-11.6-4.2.1
PrimaryStorage: hostpathstorage
BackupStorage: hostpathstorage
ReplicaStorage: hostpathstorage
BackrestStorage: hostpathstorage
PGOImageTag:  centos7-4.2.1
```

其他默认即可

2. vim $PGOROOT/pv/create-pv.sh

```
for i in {1..10}
```

默认创建100个pv，测试时调整为10个即可

3. vim $PGOROOT/pv/crunchy-pv.json

```
"hostPath": {
        "path": "/data/pgo/odev/pv/"
    }
```

并将该目录修改为 777 权限，否则后续pod使用该pv时会报权限不足

chmod 777 /data/pgo/odev/pv/

** 注 若使用hostPath 存储类型，则k8s集群中所有主机都必须创建该目录，且赋予777权限，否则也会报权限不足的错误。 **


## 4. 创建k8s 的namespace

```
make setupnamespaces
```

输出打印信息

```
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
```

确认创建namespace成功。若成功，会创建3个namespace，其中

pgo 用于operator

pgouser1/2 用于operator监控在这2个namespace的pod运行状态

namespace的名称均在 $HOME/.bashrc 中配置

```
# kubectl get ns |grep pgo
pgo                    Active   99s
pgouser1               Active   97s
pgouser2               Active   49s
```

## 5. 创建PV，即operator使用到的Storage

```
$PGOROOT/pv/create-pv.sh
```

输出的打印信息
```
create the test PV and PVC using the HostPath dir
creating PV crunchy-pv1
warning: deleting cluster-scoped resources, not scoped to the provided namespace
Error from server (NotFound): persistentvolumes "crunchy-pv1" not found
persistentvolume/crunchy-pv1 created
creating PV crunchy-pv2
warning: deleting cluster-scoped resources, not scoped to the provided namespace
Error from server (NotFound): persistentvolumes "crunchy-pv2" not found
persistentvolume/crunchy-pv2 created
```

确认pv创建成功
```
# kubectl get pv |grep crunchy-pv
crunchy-pv1                                1Gi        RWX            Retain           Available                                                   2m55s
crunchy-pv2                               1Gi        RWX            Retain           Available                                                   2m39s
crunchy-pv3                               1Gi        RWX            Retain           Available                                                   2m12s
crunchy-pv4                               1Gi        RWX            Retain           Available                                                   2m11s
crunchy-pv5                               1Gi        RWX            Retain           Available                                                   2m9s
crunchy-pv6                               1Gi        RWX            Retain           Available                                                   2m7s
crunchy-pv7                               1Gi        RWX            Retain           Available                                                   2m31s
crunchy-pv8                               1Gi        RWX            Retain           Available                                                   2m
crunchy-pv9                               1Gi        RWX            Retain           Available                                                   2m2s
crunchy-pv10                               1Gi        RWX            Retain           Available                                                   116s
```

## 6. 配置pgouser

该脚本默认安装一个pgouser，用户账号为 pgoadmin， 用户密码为 examplepassword， 用户角色为 pgoadmin。
```
$PGOROOT/deploy/install-bootstrap-creds.sh
```

并新建 $HOME/.pgouser 文件，将上述用户信息写入该隐藏文件

```
vim $HOME/.pgouser

pgoadmin:examplepassword
```

## 7. 配置RBAC (Role Based Access Controls) ，即用户认证

```
make installrbac
```

输出的打印信息

```
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
......................................+++
..........................+++
writing new private key to '/data/pgo/odev/src/github.com/crunchydata/postgres-operator-4.2.1/conf/postgres-operator/server.key'
-----
Generating public/private rsa key pair.
Your identification has been saved in /data/pgo/odev/src/github.com/crunchydata/postgres-operator-4.2.1/conf/pgo-backrest-repo/ssh_host_rsa_key.
Your public key has been saved in /data/pgo/odev/src/github.com/crunchydata/postgres-operator-4.2.1/conf/pgo-backrest-repo/ssh_host_rsa_key.pub.
The key fingerprint is:
SHA256:xYwtJcKo10N/afIEHfwNq3Vqj4/6fzCeN3mdM41l0xw root@host-10-1-241-159
The key's randomart image is:
+---[RSA 2048]----+
|     o. .oo.     |
|    . o..Bo .    |
|   . o .o.=o +   |
|  . . o oo= + oE |
|   .   .S* o o .o|
|          o o o.=|
|           . + B*|
|            ..=**|
|          .ooooo=|
+----[SHA256]-----+
```

## 8. 部署postgresql-operator

上述准备工作准备完毕后，开始部署 postgresql-operator

```
make deployoperator
```

输出的打印信息

```
cd deploy && ./deploy.sh
secret/pgo-backrest-repo-config created
secret/pgo.tls created
configmap/pgo-config created
deployment.apps/postgres-operator created
service/postgres-operator created
```

确认 postgres-operator部署成功

```
# kubectl get service postgres-operator -n pgo
NAME                TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
postgres-operator   ClusterIP   10.254.219.88   <none>        8443/TCP,4171/TCP,4150/TCP   34s
```

若确认部署成功，需在$HOME/.bashrc  文件新增一个环境变量

```
vim $HOME/.bashrc

export PGO_APISERVER_URL=https://10.254.219.88:8443
``` 

该变量的ip地址 即 返回的CLUSTER-IP 地址，端口 8443。

## 9. 验证部署是否成功

```
# kubectl get pod --selector=name=postgres-operator -n pgo
NAME                                 READY   STATUS    RESTARTS   AGE
postgres-operator-76c8564bf7-24m6j   4/4     Running   0          4m50s
```

查看pod的详细信息
```
# kubectl -n pgo describe pod postgres-operator-76c8564bf7-24m6j
Name:           postgres-operator-76c8564bf7-24m6j
Namespace:      pgo
Node:           10.1.241.159/10.1.241.159
Start Time:     Wed, 19 Feb 2020 16:15:11 +0800
Labels:         name=postgres-operator
                pod-template-hash=76c8564bf7
                vendor=crunchydata
Annotations:    <none>
Status:         Running
IP:             172.30.17.6
Controlled By:  ReplicaSet/postgres-operator-76c8564bf7
Containers:
  apiserver:
    Container ID:   docker://e39eebe1e125399f27390902e2bf55ec220e323e63943d69bf31b84d5a158b07
    Image:          crunchydata/pgo-apiserver:centos7-4.2.1
    Image ID:       docker-pullable://crunchydata/pgo-apiserver@sha256:f4452357b017bfcc1d5cd46bc41fb788676fd99f789fdc69df2d2744e6844ad6
    Port:           8443/TCP
    Host Port:      0/TCP
    State:          Running
      Started:      Wed, 19 Feb 2020 16:15:18 +0800
    Ready:          True
    Restart Count:  0
    Liveness:       http-get https://:8443/healthz delay=15s timeout=1s period=5s #success=1 #failure=3
    Readiness:      http-get https://:8443/healthz delay=15s timeout=1s period=5s #success=1 #failure=3
    Environment:
      CRUNCHY_DEBUG:           true
      PORT:                    8443
      PGO_INSTALLATION_NAME:   devtest
      PGO_OPERATOR_NAMESPACE:  pgo (v1:metadata.namespace)
      TLS_CA_TRUST:            
      TLS_NO_VERIFY:           false
      DISABLE_TLS:             false
      NOAUTH_ROUTES:           
      ADD_OS_TRUSTSTORE:       false
      DISABLE_EVENTING:        false
      EVENT_ADDR:              localhost:4150
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from postgres-operator-token-nwgjq (ro)
  operator:
    Container ID:   docker://2ac3dc308451e037249a2814a1bfc59a7f86a6722fa4266833281a68ed483050
    Image:          crunchydata/postgres-operator:centos7-4.2.1
    Image ID:       docker-pullable://crunchydata/postgres-operator@sha256:130ae1c27fdbe521de5b13bc97aeb2b7b9357dfb8a6ce53ed9fd838b238f028b
    Port:           <none>
    Host Port:      <none>
    State:          Running
      Started:      Wed, 19 Feb 2020 16:15:21 +0800
    Ready:          True
    Restart Count:  0
    Readiness:      exec [ls /tmp] delay=4s timeout=1s period=5s #success=1 #failure=3
    Environment:
      CRUNCHY_DEBUG:           true
      NAMESPACE:               pgouser1,pgouser2
      PGO_INSTALLATION_NAME:   devtest
      PGO_OPERATOR_NAMESPACE:  pgo (v1:metadata.namespace)
      MY_POD_NAME:             postgres-operator-76c8564bf7-24m6j (v1:metadata.name)
      DISABLE_EVENTING:        false
      EVENT_ADDR:              localhost:4150
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from postgres-operator-token-nwgjq (ro)
  scheduler:
    Container ID:   docker://01c2503ab028b1c51d024885a523d2583800f9b704114e66d5652400496e1d01
    Image:          crunchydata/pgo-scheduler:centos7-4.2.1
    Image ID:       docker-pullable://crunchydata/pgo-scheduler@sha256:30abab23b091e080c88b6d8a81a84bbfd096e4078c524d44f5cea85e5f70d4f1
    Port:           <none>
    Host Port:      <none>
    State:          Running
      Started:      Wed, 19 Feb 2020 16:15:24 +0800
    Ready:          True
    Restart Count:  0
    Liveness:       exec [bash -c test -n "$(find /tmp/scheduler.hb -newermt '61 sec ago')"] delay=60s timeout=1s period=60s #success=1 #failure=2
    Environment:
      CRUNCHY_DEBUG:           true
      PGO_OPERATOR_NAMESPACE:  pgo (v1:metadata.namespace)
      PGO_INSTALLATION_NAME:   devtest
      TIMEOUT:                 3600
      EVENT_ADDR:              localhost:4150
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from postgres-operator-token-nwgjq (ro)
  event:
    Container ID:   docker://9fed0866e06013874906e854d6c9226a9bea401ef98add9032add52b982755b5
    Image:          crunchydata/pgo-event:centos7-4.2.1
    Image ID:       docker-pullable://crunchydata/pgo-event@sha256:e904b1b2fb6b1434a70e53677dc549404b86a590ceec1eab6bbfc290b806a29c
    Port:           <none>
    Host Port:      <none>
    State:          Running
      Started:      Wed, 19 Feb 2020 16:15:28 +0800
    Ready:          True
    Restart Count:  0
    Liveness:       http-get http://:4151/ping delay=15s timeout=1s period=5s #success=1 #failure=3
    Environment:
      TIMEOUT:  3600
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from postgres-operator-token-nwgjq (ro)
Conditions:
  Type              Status
  Initialized       True 
  Ready             True 
  ContainersReady   True 
  PodScheduled      True 
Volumes:
  postgres-operator-token-nwgjq:
    Type:        Secret (a volume populated by a Secret)
    SecretName:  postgres-operator-token-nwgjq
    Optional:    false
QoS Class:       BestEffort
Node-Selectors:  <none>
Tolerations:     node.kubernetes.io/not-ready:NoExecute for 300s
                 node.kubernetes.io/unreachable:NoExecute for 300s
Events:
  Type    Reason     Age    From                   Message
  ----    ------     ----   ----                   -------
  Normal  Scheduled  5m53s  default-scheduler      Successfully assigned pgo/postgres-operator-76c8564bf7-24m6j to 10.1.241.159
  Normal  Pulled     5m44s  kubelet, 10.1.241.159  Container image "crunchydata/pgo-apiserver:centos7-4.2.1" already present on machine
  Normal  Created    5m43s  kubelet, 10.1.241.159  Created container apiserver
  Normal  Started    5m41s  kubelet, 10.1.241.159  Started container apiserver
  Normal  Pulled     5m41s  kubelet, 10.1.241.159  Container image "crunchydata/postgres-operator:centos7-4.2.1" already present on machine
  Normal  Created    5m39s  kubelet, 10.1.241.159  Created container operator
  Normal  Pulled     5m38s  kubelet, 10.1.241.159  Container image "crunchydata/pgo-scheduler:centos7-4.2.1" already present on machine
  Normal  Started    5m38s  kubelet, 10.1.241.159  Started container operator
  Normal  Created    5m36s  kubelet, 10.1.241.159  Created container scheduler
  Normal  Started    5m35s  kubelet, 10.1.241.159  Started container scheduler
  Normal  Pulled     5m35s  kubelet, 10.1.241.159  Container image "crunchydata/pgo-event:centos7-4.2.1" already present on machine
  Normal  Created    5m33s  kubelet, 10.1.241.159  Created container event
  Normal  Started    5m31s  kubelet, 10.1.241.159  Started container event
```

查看pod使用到的镜像文件
```
# kubectl -n pgo describe pod postgres-operator-76c8564bf7-24m6j|grep Image:
    Image:          crunchydata/pgo-apiserver:centos7-4.2.1
    Image:          crunchydata/postgres-operator:centos7-4.2.1
    Image:          crunchydata/pgo-scheduler:centos7-4.2.1
    Image:          crunchydata/pgo-event:centos7-4.2.1
```

# 安装配置pgo客户端

## 1. 安装pgo客户端
```
cd $GOPATH/bin
上传客户端软件至该目录，直接解压即可
tar -zxvf postgres-operator.4.2.1.tar.gz
```

解压后目录内容
```
# ll
total 122132
drwxr-xr-x 5 root root     4096 Jan 17 00:47 conf
drwxr-xr-x 2 root root     4096 Jan 17 00:47 deploy
drwxr-xr-x 8 root root     4096 Jan 17 00:47 examples
-rwxr-xr-x 1 root root  2372066 Jan 17 00:47 expenv
-rwxr-xr-x 1 root root  2222592 Jan 17 00:47 expenv.exe
-rwxr-xr-x 1 root root  2366392 Jan 17 00:47 expenv-mac
-rwxr-x--- 1 root root 15075342 Feb 12 09:55 go
-rwxr-x--- 1 root root  3548071 Feb 12 09:55 gofmt
-rwxr-xr-x 1 root root 34510656 Jan 17 00:47 pgo
-rw-r--r-- 1 root root    53060 Jan 17 00:47 pgo-bash-completion
-rwxr-xr-x 1 root root 30746624 Jan 17 00:47 pgo.exe
-rwxr-xr-x 1 root root 34132472 Jan 17 00:47 pgo-mac
-rw-r--r-- 1 root root 44107304 Feb 17 17:16 postgres-operator.4.2.1.tar.gz
```

验证pgo客户端安装成功

```
# pgo version
pgo client version 4.2.1
pgo-apiserver version 4.2.1
```

## 2. 配置pgo客户端

新建pgouser

```
pgo create pgouser someuser --pgouser-namespaces="pgouser1,pgouser2" --pgouser-password=somepassword --pgouser-roles="pgoadmin"
```

验证创建pgouser是否成功

```
# pgo show pgouser someuser -n pgouser1

pgouser : someuser
roles : [pgoadmin]
namespaces : [pgouser1,pgouser2]
```

若创建pgouser成功，则编辑 $HOME/.pgouser 文件，将上述新建的用户 someuser 作为第一行加入

```
vim $HOME/.bashrc

someuser:somepassword
```

** 详细参考该链接 https://access.crunchydata.com/documentation/postgres-operator/4.2.1/security/configure-postgres-operator-rbac/ **

## 3. 创建postgresql 应用

```
# pgo create cluster mycluster  --ccp-image=crunchy-postgres-ha --ccp-image-tag=centos7-11.6-4.2.1 --namespace=pgouser1
created Pgcluster mycluster
workflow id a4432e24-0b73-4c53-b1c0-628ef8fda336
```

验证 postgresql 应用部署是否成功
```
# kubectl get pod -n pgouser1
NAME                                              READY   STATUS      RESTARTS   AGE
backrest-backup-mycluster-dp2g6                   0/1     Completed   0          36m
mycluster-9b6b9799b-tqq8p                         1/1     Running     0          36m
mycluster-backrest-shared-repo-6846ffbc4c-bjvw5   1/1     Running     0          36m
mycluster-stanza-create-wfc59                     0/1     Completed   0          36m
```
一共4个pod，其中

mycluster-9b6b9799b-tqq8p 该pod即postgresql服务，数据库实例由此pod提供；

其他3个pod为辅助类，提供数据库备份等服务。

## 4. 问题排查过程中，使用到的命令
```
# kubectl get pod -n pgouser1
# kubectl -n pgouser1 describe pod mycluster-stanza-create-m4fq7
# pgo status -n pgouser1
# docker logs f493df861e86
# docker inspect  f493df861e86
# pgo show cluster mycluster -n pgouser1
# kubectl --help
# pgo --help
```

# 访问postgresql服务
## 获取postgrsql 的服务信息

```
# kubectl -n pgouser1 describe pod mycluster-9b6b9799b-tqq8p|grep conn_url
{"conn_url":"postgres://172.30.17.10:5432/postgres","api_url":"http://172.30.17.10:8009/patroni","state":"running","role":"master","versio...
```
从返回的信息，可以获取服务地址为 172.30.17.10:5432/postgres

由于该镜像默认将ip使用md5访问，且数据库的初始用户密码未提供。因此 需要通过docker exec 方式进入容器后，通过localhost方式登录后，修改密码后，方能连接。步骤如下：

1. 该容器的启动脚本为 /opt/cpm/bin/bootstrap-postgres-ha.sh，因此搜索该启动脚本
```
# docker ps|grep bootst
de02a34bc7dd        f76ab5247544                       "/opt/cpm/bin/bootst…"   About an hour ago   Up About an hour                               k8s_database_mycluster-9b6b9799b-tqq8p_pgouser1_ea171fb9-0623-4e76-a6d5-28d2a72eeb9d_0
```

容器id 为 第一列信息 ：de02a34bc7dd

2. 进入该容器

```
# docker exec -it de02a34bc7dd /bin/bash
```

3. 登录数据库，调整用户密码

```
bash-4.2$ psql -p 5432
psql (11.6)
Type "help" for help.

postgres=# alter user testuser password 'xxxxxx';
ALTER ROLE

postgres=# \l+
                                                                    List of databases
   Name    |  Owner   | Encoding |   Collate   |    Ctype    |   Access privileges   |  Size   | Tablespace |                Description                 
-----------+----------+----------+-------------+-------------+-----------------------+---------+------------+--------------------------------------------
 postgres  | postgres | UTF8     | en_US.utf-8 | en_US.utf-8 |                       | 7709 kB | pg_default | default administrative connection database
 template0 | postgres | UTF8     | en_US.utf-8 | en_US.utf-8 | =c/postgres          +| 7537 kB | pg_default | unmodifiable empty database
           |          |          |             |             | postgres=CTc/postgres |         |            | 
 template1 | postgres | UTF8     | en_US.utf-8 | en_US.utf-8 | =c/postgres          +| 7537 kB | pg_default | default template for new databases
           |          |          |             |             | postgres=CTc/postgres |         |            | 
 userdb    | postgres | UTF8     | en_US.utf-8 | en_US.utf-8 | =Tc/postgres         +| 7709 kB | pg_default | 
           |          |          |             |             | postgres=CTc/postgres+|         |            | 
           |          |          |             |             | testuser=CTc/postgres |         |            | 
(4 rows)

postgres=# \du
                                    List of roles
  Role name  |                         Attributes                         | Member of 
-------------+------------------------------------------------------------+-----------
 crunchyadm  |                                                            | {}
 postgres    | Superuser, Create role, Create DB, Replication, Bypass RLS | {}
 primaryuser | Replication                                                | {}
 testuser    |                                                            | {}

```

4. 修改密码后，可使用 虚拟ip访问了
退出该容器，使用psql连接虚拟ip访问


```
# psql -h 172.30.17.10 -p 5432 -d userdb -U testuser
Password for user testuser: 
psql (11.5, server 11.6)
Type "help" for help.

userdb=> 
```

5. 也可以使用k8s的CLUSTER-IP 访问

```
--获取CLUSTER-IP的地址
# kubectl get service -n pgouser1
NAME                             TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                                         AGE
mycluster                        ClusterIP   10.254.230.242   <none>        5432/TCP,10000/TCP,2022/TCP,9187/TCP,8009/TCP   74m
mycluster-backrest-shared-repo   ClusterIP   10.254.122.152   <none>        2022/TCP                                        74m

--通过CLUSTER-IP访问postgresql服务
# psql -h 10.254.230.242 -p 5432 -d userdb -U testuser
Password for user testuser: 
psql (11.5, server 11.6)
Type "help" for help.

userdb=> 
```

# 遇到的问题
## 1. Error: user [pgoadmin] is not allowed access to namespace [pgouser1]

**错误原因** 用户pgoadmin未配置允许接入 pgouser1 命名空间的权限

**解决方式**

1. 执行脚本配置用户pgoadmin的权限

$PGOROOT/deploy/install-bootstrap-creds.sh

2. 在~/.pgouser加入该用户的账号:密码 信息，保存即可
```
# vim ~/.pgouser 
pgoadmin:examplepassword
```

## 2. Error: user [someuser] is not allowed access to namespace [pgouser1]

**错误原因** 用户someuser未配置允许接入 pgouser1 命名空间的权限

**解决方式**

1. 执行命令配置用户someuser的权限

pgo create pgouser someuser --pgouser-namespaces="pgouser1,pgouser2" --pgouser-password=somepassword --pgouser-roles="pgoadmin"

2. 在~/.pgouser加入该用户的账号:密码 信息，保存即可
```
# vim ~/.pgouser 
someuser:somepassword
```

## 3. Error:  Authentication Failed: 401

**错误原因** 用户someuser的密码设置错误

**解决方式**

```
# cat ~/.pgouser
someuser:someuser

此处密码设置错误，按下述调整即可.

# vim ~/.pgouser
someuser:somepassword
```

## 4. pod一直处于Pending状态
**问题现象**

```
# kubectl get pod --selector=name=postgres-operator -n pgo
NAME                                 READY   STATUS    RESTARTS   AGE
postgres-operator-76c8564bf7-9km84   0/4     Pending   0          75s
```

**错误原因** 该pod所需要的镜像文件尚未拉取到本地，通过 kubectl describe pod podnamexxx 查看详细日志

**解决方式**
```
1. 通过命令kubectl describe pod，发现pod一直在拉取镜像文件 us.gcr.io/container-suite/postgres-operator:centos7-4.2.1

该镜像站点是台湾的IP，建议从dockerhub站点拉取。解决方法参考 步骤2 的描述。

# kubectl -n pgo describe pod postgres-operator-76c8564bf7-9km84
Name:           postgres-operator-76c8564bf7-9km84
Namespace:      pgo
Node:           10.1.241.159/10.1.241.159
Start Time:     Fri, 21 Feb 2020 09:41:09 +0800
Labels:         name=postgres-operator
                pod-template-hash=76c8564bf7
                vendor=crunchydata
Annotations:    <none>
Status:         Running
IP:             172.30.17.6
Controlled By:  ReplicaSet/postgres-operator-76c8564bf7
Containers:
  apiserver:
    Container ID:   docker://9b71d6014efb4134ae69df51e148c1dfeffda4023f09b956ea3bc43e0cf7dcaa
    Image:          crunchydata/pgo-apiserver:centos7-4.2.1
    Image ID:       docker-pullable://crunchydata/pgo-apiserver@sha256:f4452357b017bfcc1d5cd46bc41fb788676fd99f789fdc69df2d2744e6844ad6
    Port:           8443/TCP
    Host Port:      0/TCP
    State:          Running
      Started:      Fri, 21 Feb 2020 09:41:15 +0800
    Ready:          True
    Restart Count:  0
    Liveness:       http-get https://:8443/healthz delay=15s timeout=1s period=5s #success=1 #failure=3
    Readiness:      http-get https://:8443/healthz delay=15s timeout=1s period=5s #success=1 #failure=3
    Environment:
      CRUNCHY_DEBUG:           true
      PORT:                    8443
      PGO_INSTALLATION_NAME:   devtest
      PGO_OPERATOR_NAMESPACE:  pgo (v1:metadata.namespace)
      TLS_CA_TRUST:            
      TLS_NO_VERIFY:           false
      DISABLE_TLS:             false
      NOAUTH_ROUTES:           
      ADD_OS_TRUSTSTORE:       false
      DISABLE_EVENTING:        false
      EVENT_ADDR:              localhost:4150
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from postgres-operator-token-bzkj5 (ro)
  operator:
    Container ID:   docker://d62fd5f1a69095becddf0bb39f3629e4d132e431fb792187d7ee8d5782b0020e
    Image:          crunchydata/postgres-operator:centos7-4.2.1
    Image ID:       docker-pullable://crunchydata/postgres-operator@sha256:130ae1c27fdbe521de5b13bc97aeb2b7b9357dfb8a6ce53ed9fd838b238f028b
    Port:           <none>
    Host Port:      <none>
    State:          Running
      Started:      Fri, 21 Feb 2020 09:41:50 +0800
    Ready:          True
    Restart Count:  0
    Readiness:      exec [ls /tmp] delay=4s timeout=1s period=5s #success=1 #failure=3
    Environment:
      CRUNCHY_DEBUG:           true
      NAMESPACE:               pgouser1,pgouser2
      PGO_INSTALLATION_NAME:   devtest
      PGO_OPERATOR_NAMESPACE:  pgo (v1:metadata.namespace)
      MY_POD_NAME:             postgres-operator-76c8564bf7-9km84 (v1:metadata.name)
      DISABLE_EVENTING:        false
      EVENT_ADDR:              localhost:4150
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from postgres-operator-token-bzkj5 (ro)
  scheduler:
    Container ID:   docker://7d57353d4ac67c85344f365ce787023b445c2756b7bfbdc6fb7cc8d3e5955194
    Image:          crunchydata/pgo-scheduler:centos7-4.2.1
    Image ID:       docker-pullable://crunchydata/pgo-scheduler@sha256:30abab23b091e080c88b6d8a81a84bbfd096e4078c524d44f5cea85e5f70d4f1
    Port:           <none>
    Host Port:      <none>
    State:          Running
      Started:      Fri, 21 Feb 2020 09:41:53 +0800
    Ready:          True
    Restart Count:  0
    Liveness:       exec [bash -c test -n "$(find /tmp/scheduler.hb -newermt '61 sec ago')"] delay=60s timeout=1s period=60s #success=1 #failure=2
    Environment:
      CRUNCHY_DEBUG:           true
      PGO_OPERATOR_NAMESPACE:  pgo (v1:metadata.namespace)
      PGO_INSTALLATION_NAME:   devtest
      TIMEOUT:                 3600
      EVENT_ADDR:              localhost:4150
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from postgres-operator-token-bzkj5 (ro)
  event:
    Container ID:   docker://2f57426888849ba569585b6c6bb216f00825baa83b5468d3541c088c260ca64d
    Image:          crunchydata/pgo-event:centos7-4.2.1
    Image ID:       docker-pullable://crunchydata/pgo-event@sha256:e904b1b2fb6b1434a70e53677dc549404b86a590ceec1eab6bbfc290b806a29c
    Port:           <none>
    Host Port:      <none>
    State:          Running
      Started:      Fri, 21 Feb 2020 09:41:56 +0800
    Ready:          True
    Restart Count:  0
    Liveness:       http-get http://:4151/ping delay=15s timeout=1s period=5s #success=1 #failure=3
    Environment:
      TIMEOUT:  3600
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from postgres-operator-token-bzkj5 (ro)
Conditions:
  Type              Status
  Initialized       True 
  Ready             True 
  ContainersReady   True 
  PodScheduled      True 
Volumes:
  postgres-operator-token-bzkj5:
    Type:        Secret (a volume populated by a Secret)
    SecretName:  postgres-operator-token-bzkj5
    Optional:    false
QoS Class:       BestEffort
Node-Selectors:  <none>
Tolerations:     node.kubernetes.io/not-ready:NoExecute for 300s
                 node.kubernetes.io/unreachable:NoExecute for 300s
Events:
  Type    Reason     Age   From                   Message
  ----    ------     ----  ----                   -------
  Normal  Scheduled  85s   default-scheduler      Successfully assigned pgo/postgres-operator-76c8564bf7-9km84 to 10.1.241.159
  Normal  Pulled     77s   kubelet, 10.1.241.159  Container image "crunchydata/pgo-apiserver:centos7-4.2.1" already present on machine
  Normal  Created    75s   kubelet, 10.1.241.159  Created container apiserver
  Normal  Started    75s   kubelet, 10.1.241.159  Started container apiserver
  Normal  Pulling    75s   kubelet, 10.1.241.159  Pulling image "us.gcr.io/container-suite/postgres-operator:centos7-4.2.1"

2. 参考章节 [需要准备的镜像] 段落，修改镜像站点的域名，执行shell脚本批量下载到本地即可。

也可以通过手工命令拉取，但手工拉取不一定能拉全所有镜像。建议使用shell脚本批量下载。

docker pull crunchydata/postgres-operator:centos7-4.2.1

```

## 5. pod 一直处于CrashLoopBackOff状态，频繁重启
**问题现象**
```
# kubectl get pod -n pgouser1
NAME                                              READY   STATUS             RESTARTS   AGE
mycluster-backrest-shared-repo-6846ffbc4c-lnch9   0/1     Pending            0          89s
mycluster-cb44d9874-2xwnk                         0/1     CrashLoopBackOff   3          89s
```

**错误原因** 原因很多，此处我遇到的该问题原因是 initdb: could not create directory "/pgdata/mycluster": Permission denied

**解决方式**

```
1. 通过命令kubectl describe pod，发现该pod启动在 10.1.241.161 物理机，需登录到该物理机 使用 docker logs 命令继续分析根本原因。

**(注，补充下k8s集群信息 k8s集群由3台物理机构成，10.1.241.159/160/161 ，其中159是操作所在主机)**

# kubectl -n pgouser1 describe pod mycluster-cb44d9874-2xwnk 
Name:           mycluster-cb44d9874-2xwnk
Namespace:      pgouser1
Node:           10.1.241.161/10.1.241.161
Start Time:     Fri, 21 Feb 2020 09:55:38 +0800
Labels:         archive-timeout=60
                crunchy-pgha-scope=mycluster
                crunchy_collect=false
                deployment-name=mycluster
                name=mycluster
                pg-cluster=mycluster
                pg-cluster-id=a2ec4a31-88d3-49da-81d0-747afdcc41cd
                pg-pod-anti-affinity=
                pgo-pg-database=true
                pgo-version=4.2.1
                pgouser=someuser
                pod-template-hash=cb44d9874
                service-name=mycluster
                vendor=crunchydata
                workflowid=22c18901-2acc-4ebd-bd97-39f4e8e135be
Annotations:    status:
                  {"conn_url":"postgres://172.30.53.27:5432/postgres","api_url":"http://172.30.53.27:8009/patroni","state":"stopped","role":"uninitialized",...
Status:         Running
IP:             172.30.53.27
Controlled By:  ReplicaSet/mycluster-cb44d9874
Containers:
  database:
    Container ID:   docker://027852cd1de2079e6945c9fb3686db048b2880b6c4f65f72497bf0b180d134ca
    Image:          crunchydata/crunchy-postgres-ha:centos7-11.6-4.2.1
    Image ID:       docker-pullable://crunchydata/crunchy-postgres-ha@sha256:ab5a0b020394e61156c1142f05e00d11ca43fb46698123fd3c4b74165af18dcb
    Ports:          5432/TCP, 8009/TCP
    Host Ports:     0/TCP, 0/TCP
    State:          Terminated
      Reason:       Completed
      Exit Code:    0
      Started:      Fri, 21 Feb 2020 09:57:38 +0800
      Finished:     Fri, 21 Feb 2020 09:57:41 +0800
    Last State:     Terminated
      Reason:       Completed
      Exit Code:    0
      Started:      Fri, 21 Feb 2020 09:56:39 +0800
      Finished:     Fri, 21 Feb 2020 09:56:43 +0800
    Ready:          False
    Restart Count:  4
    Liveness:       exec [/opt/cpm/bin/pgha-liveness.sh] delay=30s timeout=10s period=15s #success=1 #failure=3
    Readiness:      exec [/opt/cpm/bin/pgha-readiness.sh] delay=15s timeout=1s period=10s #success=1 #failure=3
    Environment:
      PGHA_PG_PORT:                       5432
      PGHA_USER:                          postgres
      PGHA_INIT:                          <set to the key 'init' of config map 'mycluster-pgha-default-config'>  Optional: false
      PATRONI_POSTGRESQL_DATA_DIR:        /pgdata/mycluster
      PGBACKREST_STANZA:                  db
      PGBACKREST_REPO1_HOST:              mycluster-backrest-shared-repo
      BACKREST_SKIP_CREATE_STANZA:        true
      PGHA_PGBACKREST:                    true
      PGBACKREST_REPO1_PATH:              /backrestrepo/mycluster-backrest-shared-repo
      PGBACKREST_DB_PATH:                 /pgdata/mycluster
      ENABLE_SSHD:                        true
      PGBACKREST_LOG_PATH:                /tmp
      PGBACKREST_PG1_SOCKET_PATH:         /tmp
      PGBACKREST_PG1_PORT:                5432
      PGBACKREST_REPO_TYPE:               posix
      PGHA_PGBACKREST_LOCAL_S3_STORAGE:   false
      PGHA_DATABASE:                      userdb
      PGHA_CRUNCHYADM:                    true
      PGHA_REPLICA_REINIT_ON_START_FAIL:  true
      PGHA_SYNC_REPLICATION:              false
      PATRONI_KUBERNETES_NAMESPACE:       pgouser1 (v1:metadata.namespace)
      PATRONI_KUBERNETES_SCOPE_LABEL:     crunchy-pgha-scope
      PATRONI_SCOPE:                       (v1:metadata.labels['crunchy-pgha-scope'])
      PATRONI_KUBERNETES_LABELS:          {vendor: "crunchydata"}
      PATRONI_LOG_LEVEL:                  INFO
      PGHOST:                             /tmp
    Mounts:
      /backrestrepo from backrestrepo (rw)
      /crunchyadm from crunchyadm (rw)
      /pgconf from pgconf-volume (rw)
      /pgconf/pgreplicator from primary-volume (rw)
      /pgconf/pgsuper from root-volume (rw)
      /pgconf/pguser from user-volume (rw)
      /pgdata from pgdata (rw)
      /pgwal from pgwal-volume (rw)
      /recover from recover-volume (rw)
      /sshd from sshd (ro)
      /var/run/secrets/kubernetes.io/serviceaccount from pgo-pg-token-pnp2w (ro)
Conditions:
  Type              Status
  Initialized       True 
  Ready             False 
  ContainersReady   False 
  PodScheduled      True 
Volumes:
  pgdata:
    Type:       PersistentVolumeClaim (a reference to a PersistentVolumeClaim in the same namespace)
    ClaimName:  mycluster
    ReadOnly:   false
  user-volume:
    Type:        Secret (a volume populated by a Secret)
    SecretName:  mycluster-testuser-secret
    Optional:    false
  primary-volume:
    Type:        Secret (a volume populated by a Secret)
    SecretName:  mycluster-primaryuser-secret
    Optional:    false
  collect-volume:
    Type:       EmptyDir (a temporary directory that shares a pod's lifetime)
    Medium:     
    SizeLimit:  <unset>
  sshd:
    Type:        Secret (a volume populated by a Secret)
    SecretName:  mycluster-backrest-repo-config
    Optional:    false
  root-volume:
    Type:        Secret (a volume populated by a Secret)
    SecretName:  mycluster-postgres-secret
    Optional:    false
  pgwal-volume:
    Type:       EmptyDir (a temporary directory that shares a pod's lifetime)
    Medium:     Memory
    SizeLimit:  <unset>
  recover-volume:
    Type:       EmptyDir (a temporary directory that shares a pod's lifetime)
    Medium:     Memory
    SizeLimit:  <unset>
  report:
    Type:       EmptyDir (a temporary directory that shares a pod's lifetime)
    Medium:     Memory
    SizeLimit:  <unset>
  backrestrepo:
    Type:       EmptyDir (a temporary directory that shares a pod's lifetime)
    Medium:     Memory
    SizeLimit:  <unset>
  crunchyadm:
    Type:       EmptyDir (a temporary directory that shares a pod's lifetime)
    Medium:     
    SizeLimit:  <unset>
  pgconf-volume:
    Type:               Projected (a volume that contains injected data from multiple sources)
    ConfigMapName:      mycluster-pgha-default-config
    ConfigMapOptional:  0xc0003a5cf9
  pgo-pg-token-pnp2w:
    Type:        Secret (a volume populated by a Secret)
    SecretName:  pgo-pg-token-pnp2w
    Optional:    false
QoS Class:       BestEffort
Node-Selectors:  <none>
Tolerations:     node.kubernetes.io/not-ready:NoExecute for 300s
                 node.kubernetes.io/unreachable:NoExecute for 300s
Events:
  Type     Reason     Age                  From                   Message
  ----     ------     ----                 ----                   -------
  Normal   Scheduled  2m10s                default-scheduler      Successfully assigned pgouser1/mycluster-cb44d9874-2xwnk to 10.1.241.161
  Normal   Started    68s (x4 over 2m5s)   kubelet, 10.1.241.161  Started container database
  Warning  BackOff    27s (x11 over 115s)  kubelet, 10.1.241.161  Back-off restarting failed container
  Normal   Pulled     13s (x5 over 2m6s)   kubelet, 10.1.241.161  Container image "crunchydata/crunchy-postgres-ha:centos7-11.6-4.2.1" already present on machine
  Normal   Created    11s (x5 over 2m5s)   kubelet, 10.1.241.161  Created container database

2. 登录10.1.241.161主机，使用docker ps -a 发现一个状态为 Exited (0) 的容器，且启动命令为/opt/cpm/bin/bootstrap-postgres-ha.sh的容器。找到了报错的容器了。继续使用docker logs 分析

# docker ps -a|more
CONTAINER ID        IMAGE                                     COMMAND                  CREATED             STATUS                      PORTS              
                             NAMES
fdad856abd6a        f76ab5247544                              "/opt/cpm/bin/bootst…"   19 seconds ago      Exited (0) 14 seconds ago                      
                             k8s_database_mycluster-cb44d9874-2xwnk_pgouser1_5d07bb32-2f26-4007-a3b7-de8315a038c8_7

3. 通过docker logs，终于定位到根本原因 。显示/pgdata/mycluster 没权限创建该目录。使用docker inspect查看该目录是如何绑定的

mkdir: cannot create directory ‘/pgdata/mycluster’: Permission denied

chmod: cannot access ‘/pgdata/mycluster’: No such file or directory

# docker logs fdad856abd6a
Fri Feb 21 02:06:54 UTC 2020 INFO: postgres-ha pre-bootstrap starting...
Fri Feb 21 02:06:54 UTC 2020 INFO: pgBackRest auto-config disabled
Fri Feb 21 02:06:54 UTC 2020 INFO: PGHA_PGBACKREST_LOCAL_S3_STORAGE and PGHA_PGBACKREST_INITIALIZE will be ignored if provided
Fri Feb 21 02:06:54 UTC 2020 INFO: Defaults have been set for the following postgres-ha auto-configuration env vars: PGHA_DEFAULT_CONFIG, PGHA_BASE_BOOTSTRAP_CONFIG, PGHA_BASE_PG_CONFIG, PGHA_ENABLE_WALDIR
Fri Feb 21 02:06:54 UTC 2020 INFO: The use of the /pgwal directory for writing WAL is not enabled
Fri Feb 21 02:06:54 UTC 2020 INFO: A default value will not be set for PGHA_WALDIR and any value provided for will be ignored
Fri Feb 21 02:06:54 UTC 2020 INFO: Defaults have been set for the following postgres-ha env vars: PGHA_PATRONI_PORT
Fri Feb 21 02:06:54 UTC 2020 INFO: Defaults have been set for the following Patroni env vars: PATRONI_NAME, PATRONI_RESTAPI_LISTEN, PATRONI_RESTAPI_CONNECT_ADDRESS, PATRONI_POSTGRESQL_LISTEN, PATRONI_POSTGRESQL_CONNECT_ADDRESS
Fri Feb 21 02:06:54 UTC 2020 INFO: Setting postgres-ha configuration for database user credentials
Fri Feb 21 02:06:54 UTC 2020 INFO: Setting 'pguser' credentials using file system
Fri Feb 21 02:06:54 UTC 2020 INFO: Setting 'superuser' credentials using file system
Fri Feb 21 02:06:54 UTC 2020 INFO: Setting 'replicator' credentials using file system
Fri Feb 21 02:06:54 UTC 2020 INFO: Applying base bootstrap config to postgres-ha configuration
Fri Feb 21 02:06:54 UTC 2020 INFO: Applying base postgres config to postgres-ha configuration
Fri Feb 21 02:06:54 UTC 2020 INFO: Default WAL directory will be utilized.  Any value provided for PGHA_WALDIR will be ignored
Fri Feb 21 02:06:54 UTC 2020 INFO: Applying pgbackrest config to postgres-ha configuration
Fri Feb 21 02:06:54 UTC 2020 INFO: PGDATA directory is empty on node identifed as Primary
Fri Feb 21 02:06:54 UTC 2020 INFO: initdb configuration will be applied to intitilize a new database
Fri Feb 21 02:06:54 UTC 2020 INFO: Applying custom postgres-ha configuration file
Fri Feb 21 02:06:55 UTC 2020 INFO: Finished building postgres-ha configuration file '/tmp/postgres-ha-bootstrap.yaml'
mkdir: cannot create directory ‘/pgdata/mycluster’: Permission denied
chmod: cannot access ‘/pgdata/mycluster’: No such file or directory
Fri Feb 21 02:06:55 UTC 2020 INFO: postgres-ha pre-bootstrap complete!  The following configuration will be utilized to initialize 
******************************
postgres-ha (PGHA) env vars:
******************************
PGHA_DEFAULT_CONFIG=true
PGHA_REPLICA_REINIT_ON_START_FAIL=true
PGHA_PGBACKREST_LOCAL_S3_STORAGE=false
PGHA_PGBACKREST=true
PGHA_PATRONI_PORT=8009
PGHA_PG_PORT=5432
PGHA_USER=postgres
PGHA_CRUNCHYADM=true
PGHA_ENABLE_WALDIR=false
PGHA_BASE_BOOTSTRAP_CONFIG=true
PGHA_DATABASE=userdb
PGHA_BASE_PG_CONFIG=true
PGHA_SYNC_REPLICATION=false
PGHA_INIT=true
******************************
Patroni env vars:
******************************
PATRONI_LOG_LEVEL=INFO
PATRONI_KUBERNETES_SCOPE_LABEL=crunchy-pgha-scope
PATRONI_KUBERNETES_NAMESPACE=pgouser1
PATRONI_SCOPE=mycluster
PATRONI_POSTGRESQL_DATA_DIR=/pgdata/mycluster
PATRONI_POSTGRESQL_LISTEN=0.0.0.0:5432
PATRONI_RESTAPI_LISTEN=0.0.0.0:8009
PATRONI_KUBERNETES_LABELS={vendor: "crunchydata"}
PATRONI_POSTGRESQL_CONNECT_ADDRESS=172.30.53.27:5432
PATRONI_RESTAPI_CONNECT_ADDRESS=172.30.53.27:8009
PATRONI_NAME=mycluster-cb44d9874-2xwnk
******************************
Patroni configuration file:
******************************
bootstrap:
  dcs:
    postgresql:
      parameters:
        archive_command: source /tmp/pgbackrest_env.sh && pgbackrest archive-push
          "%p"
        archive_mode: true
        archive_timeout: 60
        log_directory: pg_log
        log_min_duration_statement: 60000
        log_statement: none
        max_wal_senders: 6
        shared_buffers: 128MB
        shared_preload_libraries: pgaudit.so,pg_stat_statements.so
        temp_buffers: 8MB
        unix_socket_directories: /tmp,/crunchyadm
        work_mem: 4MB
      recovery_conf:
        restore_command: source /tmp/pgbackrest_env.sh && pgbackrest archive-get %f
          "%p"
      use_pg_rewind: true
      use_slots: false
  initdb:
  - encoding: UTF8
  post_bootstrap: /opt/cpm/bin/post-bootstrap.sh
postgresql:
  callbacks:
    on_role_change: /opt/cpm/bin/pgha-on-role-change.sh
  create_replica_methods:
  - pgbackrest
  - basebackup
  pg_hba:
  - local all postgres peer
  - local all crunchyadm peer
  - host replication primaryuser 0.0.0.0/0 md5
  - host all primaryuser 0.0.0.0/0 reject
  - host all all 0.0.0.0/0 md5
  pgbackrest:
    command: /opt/cpm/bin/pgbackrest-create-replica.sh
    keep_data: true
    no_params: true
  pgpass: /tmp/.pgpass
  remove_data_directory_on_rewind_failure: true
  use_unix_socket: true
Fri Feb 21 02:06:55 UTC 2020 INFO: pgBackRest: The following pgbackrest env vars have been set:
PGBACKREST_REPO1_HOST=mycluster-backrest-shared-repo
PGBACKREST_STANZA=db
PGBACKREST_PG1_SOCKET_PATH=/tmp
PGBACKREST_REPO_TYPE=posix
PGBACKREST_DB_PATH=/pgdata/mycluster
PGBACKREST_LOG_PATH=/tmp
PGBACKREST_PG1_PORT=5432
PGBACKREST_REPO1_PATH=/backrestrepo/mycluster-backrest-shared-repo
Fri Feb 21 02:06:55 UTC 2020 INFO: Applying SSHD..
Fri Feb 21 02:06:55 UTC 2020 INFO: Checking for SSH Host Keys in /sshd..
Fri Feb 21 02:06:55 UTC 2020 INFO: Checking for authorized_keys in /sshd
Fri Feb 21 02:06:55 UTC 2020 INFO: Checking for sshd_config in /sshd
Fri Feb 21 02:06:55 UTC 2020 INFO: setting up .ssh directory
Fri Feb 21 02:06:55 UTC 2020 INFO: Starting SSHD..
WARNING: 'UsePAM no' is not supported in Red Hat Enterprise Linux and may cause several problems.
Fri Feb 21 02:06:55 UTC 2020 INFO: Starting background process to monitor Patroni initization and restart the database if needed
Fri Feb 21 02:06:55 UTC 2020 INFO: Initializing cluster bootstrap with command: '/usr/local/bin/patroni /tmp/postgres-ha-bootstrap.yaml'
Fri Feb 21 02:06:55 UTC 2020 INFO: Running Patroni as PID 1
2020-02-21 02:06:57,265 INFO: No PostgreSQL configuration items changed, nothing to reload.
2020-02-21 02:06:57,274 INFO: Lock owner: None; I am mycluster-cb44d9874-2xwnk
2020-02-21 02:06:57,312 INFO: trying to bootstrap a new cluster
initdb: could not create directory "/pgdata/mycluster": Permission denied
pg_ctl: database system initialization failed
The files belonging to this database system will be owned by user "postgres".
This user must also own the server process.

The database cluster will be initialized with locale "en_US.utf-8".
The default text search configuration will be set to "english".

Data page checksums are disabled.

2020-02-21 02:06:57,461 INFO: removing initialize key after failed attempt to bootstrap the cluster
2020-02-21 02:06:57,774 INFO: Lock owner: None; I am mycluster-cb44d9874-2xwnk
Process Process-1:
Traceback (most recent call last):
  File "/usr/lib64/python3.6/multiprocessing/process.py", line 258, in _bootstrap
    self.run()
  File "/usr/lib64/python3.6/multiprocessing/process.py", line 93, in run
    self._target(*self._args, **self._kwargs)
  File "/usr/local/lib/python3.6/site-packages/patroni/__init__.py", line 185, in patroni_main
    patroni.run()
  File "/usr/local/lib/python3.6/site-packages/patroni/__init__.py", line 134, in run
    logger.info(self.ha.run_cycle())
  File "/usr/local/lib/python3.6/site-packages/patroni/ha.py", line 1336, in run_cycle
    info = self._run_cycle()
  File "/usr/local/lib/python3.6/site-packages/patroni/ha.py", line 1244, in _run_cycle
    return self.post_bootstrap()
  File "/usr/local/lib/python3.6/site-packages/patroni/ha.py", line 1141, in post_bootstrap
    self.cancel_initialization()
  File "/usr/local/lib/python3.6/site-packages/patroni/ha.py", line 1136, in cancel_initialization
    raise PatroniException('Failed to bootstrap cluster')
patroni.exceptions.PatroniException: 'Failed to bootstrap cluster'
creating directory /pgdata/mycluster ... 

4. 使用docker inspect，发现该目录绑定到PV的目录 /data/pgo/odev/pv/，检查/data/pgo/odev/pv/的目录权限是否为 777

# docker inspect fdad856abd6a
····
"HostConfig": {
            "Binds": [
                "/data/pgo/odev/pv/:/pgdata",
···

5. 发现目录权限只有755。 根本原因已经定位，调整为 777 即可。k8s集群所有主机的该目录都需要调整为777，否则pod漂移至其他主机，也会报相同的错误。

# ll /data/pgo/odev/
total 4
drwxr-xr-x 3 root root 4096 Feb 20 09:45 pv

# chmod 777 /data/pgo/odev/pv

问题解决。再次查看当前pod的状态。mycluster-cb44d9874-2xwnk 已显示 Running状态。

问题6 会继续分析 mycluster-backrest-shared-repo-6846ffbc4c-lnch9 为啥处于Pending状态。

# kubectl get pod -n pgouser1
NAME                                              READY   STATUS    RESTARTS   AGE
mycluster-backrest-shared-repo-6846ffbc4c-lnch9   0/1     Pending   0          21m
mycluster-cb44d9874-2xwnk                         0/1     Running   9          21m
```

## 6. mycluster-backrest-shared-repo-6846ffbc4c-lnch9一直处于Pending

**错误原因** 解决思路同问题5，通过 kubectl describe pod 一步一步深入分析即可。

**解决方式**
```
1. 通过下述命令，发现该pod未绑定pv

# kubectl -n pgouser1 describe pod mycluster-backrest-shared-repo-6846ffbc4c-lnch9

Events:
  Type     Reason            Age                 From               Message
  ----     ------            ----                ----               -------
  Warning  FailedScheduling  80s (x16 over 22m)  default-scheduler  pod has unbound immediate PersistentVolumeClaims (repeated 3 times)

2. 查看pv的状态，发现只有一个pv，且该pv已经绑定了。原因已经定位了，多建几个pv即可。

# kubectl get pv|grep crunchy
crunchy-pv1                                1Gi        RWX            Retain           Bound    pgouser1/mycluster                              53m

3. 新建10个pv之后，再次查看pod的状态。该pod已经显示Running状态。问题7 继续分析mycluster-stanza-create-j8nvn的Error原因

# kubectl get pod -n pgouser1
NAME                                              READY   STATUS    RESTARTS   AGE
mycluster-backrest-shared-repo-6846ffbc4c-lnch9   1/1     Running   0          30m
mycluster-cb44d9874-2xwnk                         1/1     Running   9          30m
mycluster-stanza-create-j8nvn                     0/1     Error     0          8m9s

```

## 7. mycluster-stanza-create-j8nvn一直处于Error

**错误原因** 解决思路同问题5，通过 kubectl describe pod 一步一步深入分析即可。

**解决方式**
```
1. 通过 kubectl describe pod，没有发现很明显的报错。显示该容器的退出码是2( Exit Code:    2)，该容器所在主机 10.1.241.159。

只能登陆159主机，查出该容器，使用docker logs 继续分析。

# kubectl -n pgouser1 describe pod mycluster-stanza-create-j8nvn
Name:           mycluster-stanza-create-j8nvn
Namespace:      pgouser1
Node:           10.1.241.159/10.1.241.159
Start Time:     Fri, 21 Feb 2020 10:17:50 +0800
Labels:         backrest-command=stanza-create
                controller-uid=f3a69ad7-a6c5-4dcf-afb8-e58a36dcd3bc
                job-name=mycluster-stanza-create
                pg-cluster=mycluster
                pgo-backrest=true
                pgo-backrest-job=true
                vendor=crunchydata
Annotations:    <none>
Status:         Failed
IP:             172.30.17.10
Controlled By:  Job/mycluster-stanza-create
Containers:
  backrest:
    Container ID:   docker://9ef908f921d63603a2b167e8288a97e8f4a118e19ac8e0d054bb1c8ebe923e72
    Image:          crunchydata/pgo-backrest:centos7-4.2.1
    Image ID:       docker-pullable://crunchydata/pgo-backrest@sha256:404b45f897e56679fee78f822c83d9360a8f0384f419b9827af0a2a3b5979671
    Port:           <none>
    Host Port:      <none>
    State:          Terminated
      Reason:       Error
      Exit Code:    2
      Started:      Fri, 21 Feb 2020 10:18:11 +0800
      Finished:     Fri, 21 Feb 2020 10:18:11 +0800
    Ready:          False
    Restart Count:  0
    Environment:
      COMMAND:                           stanza-create
      COMMAND_OPTS:                       --db-host=172.30.53.27 --db-path=/pgdata/mycluster
      PITR_TARGET:                       
      PODNAME:                           mycluster-backrest-shared-repo-6846ffbc4c-lnch9
      PGBACKREST_STANZA:                 
      PGBACKREST_DB_PATH:                
      PGBACKREST_REPO_PATH:              
      PGBACKREST_REPO_TYPE:              posix
      PGHA_PGBACKREST_LOCAL_S3_STORAGE:  false
      PGBACKREST_LOG_PATH:               /tmp
      NAMESPACE:                         pgouser1 (v1:metadata.namespace)
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from pgo-backrest-token-p6vpf (ro)
Conditions:
  Type              Status
  Initialized       True 
  Ready             False 
  ContainersReady   False 
  PodScheduled      True 
Volumes:
  pgo-backrest-token-p6vpf:
    Type:        Secret (a volume populated by a Secret)
    SecretName:  pgo-backrest-token-p6vpf
    Optional:    false
QoS Class:       BestEffort
Node-Selectors:  <none>
Tolerations:     node.kubernetes.io/not-ready:NoExecute for 300s
                 node.kubernetes.io/unreachable:NoExecute for 300s
Events:
  Type    Reason     Age   From                   Message
  ----    ------     ----  ----                   -------
  Normal  Scheduled  11m   default-scheduler      Successfully assigned pgouser1/mycluster-stanza-create-j8nvn to 10.1.241.159
  Normal  Pulled     11m   kubelet, 10.1.241.159  Container image "crunchydata/pgo-backrest:centos7-4.2.1" already present on machine
  Normal  Created    11m   kubelet, 10.1.241.159  Created container backrest
  Normal  Started    11m   kubelet, 10.1.241.159  Started container backrest

2. 使用docker ps -a  的确存在一个退出码是 2 的容器

# docker ps -a|more
CONTAINER ID        IMAGE                                    COMMAND                  CREATED             STATUS                      PORTS               
       NAMES
9ef908f921d6        3dfef6e37271                             "/opt/cpm/bin/uid_po…"   13 minutes ago      Exited (2) 12 minutes ago                       
       k8s_backrest_mycluster-stanza-create-j8nvn_pgouser1_227815c2-ef45-4bf7-aaf5-e75ad3f290fc_0

3. 通过docker logs，发现该pod未分配主机，未被调度到。重建该集群即可。

# docker logs 9ef908f921d6
time="2020-02-21T02:18:11Z" level=info msg="pgo-backrest starts"
time="2020-02-21T02:18:11Z" level=info msg="debug flag set to false"
time="2020-02-21T02:18:11Z" level=info msg="backrest stanza-create command requested"
time="2020-02-21T02:18:11Z" level=info msg="command to execute is [pgbackrest stanza-create  --db-host=172.30.53.27 --db-path=/pgdata/mycluster]"
time="2020-02-21T02:18:11Z" level=info msg="command is pgbackrest stanza-create  --db-host=172.30.53.27 --db-path=/pgdata/mycluster "
time="2020-02-21T02:18:11Z" level=error msg="pod mycluster-backrest-shared-repo-6846ffbc4c-lnch9 does not have a host assigned"
time="2020-02-21T02:18:11Z" level=info msg="output=[]"
time="2020-02-21T02:18:11Z" level=info msg="stderr=[]"
time="2020-02-21T02:18:11Z" level=error msg="pod mycluster-backrest-shared-repo-6846ffbc4c-lnch9 does not have a host assigned"

4. 重建该集群
--删除该集群
# pgo delete cluster mycluster -n pgouser1
WARNING - This will delete ALL OF YOUR DATA, including backups. Proceed? (yes/no): yes
deleted pgcluster mycluster

--k8s集群所有主机，删除pv上的文件
# rm -Rf /data/pgo/odev/pv/*

--重建该集群
# pgo create cluster mycluster  --ccp-image=crunchy-postgres-ha --ccp-image-tag=centos7-11.6-4.2.1 --namespace=pgouser1
created Pgcluster mycluster
workflow id bcc0a409-e2b5-401f-a254-73234591eb24

--查看当前状态，所有pod均处于正常状态，部署成功。
# kubectl get pod -n pgouser1
NAME                                              READY   STATUS      RESTARTS   AGE
backrest-backup-mycluster-pn56c                   0/1     Completed   0          6m24s
mycluster-5b9d564c47-6qwb2                        1/1     Running     0          7m27s
mycluster-backrest-shared-repo-6846ffbc4c-dwsz4   1/1     Running     0          7m29s
mycluster-stanza-create-hqds8                     0/1     Completed   0          7m7s
```


# 总结
官方提供的postgresql镜像已部署成功，后续在使用/ha切换和其他一些方面，仍需测试验证。

另外，AntDB单机版如何部署到k8s，需要结合本次经验从头开始探索，主要涉及的镜像较多，且k8s原理复杂，且两者需要结合考虑，难度不小。

# 参考
AntDB QQ群号：496464280

[AntDB github链接](https://github.com/ADBSQL)
