# AntDB 集群版基于k8s的operator有状态部署
***
本文主要探讨AntDB 集群版基于k8s通过operator实现有状态部署的实施方案。
通过本文实现下述功能：
* AntDB 集群版相关概念说明
* AntDB 集群版部署操作说明
* 验证pod重启之后，AntDB集群不需要任何调整，仍可继续正常使用，且数据正确

***

# 1. 概述
## 1.1 版本说明
|版本名称|支持的版本号|下载链接|本次测试环境版本|
|:-----|:-------|:-------|:-------|
|postgres-operator 服务端版本|4.2.1+|https://github.com/CrunchyData/postgres-operator/tree/v4.2.1|4.2.1|
|postgres-operator 客户端版本(pgo)|4.2.1+|https://github.com/CrunchyData/postgres-operator/releases/download/v4.2.1/postgres-operator.4.2.1.tar.gz|4.2.1|
|kubernetes 版本|1.13+||1.17.3|
|docker 版本|18.09.8+||19.03.7|
|go 版本|1.13.7+|https://dl.google.com/go/go1.13.7.linux-amd64.tar.gz|1.13.7|
|expenv 版本|1.2.0+|https://github.com/blang/expenv，expenv已在pgo客户端版本集成，但不用单独安装，直接安装pgo即可|1.2.0|
|AntDB 版本|5.0devel a8a0374，集群版|AntDB团队|antdb.cluster-5.0.a8a0374|
|容器内os 版本|centos7||centos 7.7|

## 1.2 支持的K8s storage类型说明
本次测试环境的PV使用 HostPath 存储类型

* HostPath
* NFS
* StorageOS
* Rook
* Google Compute Engine persistent volumes

and more.

## 1.3 端口规划
以下涉及的端口，建议全部使用默认，不要更改。
### 1.3.1 容器端口规划
|容器|端口|配置文件路径|
|:-----|:-------|:----|
|API Server|8443|$HOME/.bashrc|
|nsqadmin|4151|$PGOROOT/deploy/deployment.json 和 $PGOROOT/deploy/service.json|
|nsqd|4150|$PGOROOT/deploy/deployment.json 和 $PGOROOT/deploy/service.json|

### 1.3.2 服务端口规划
|服务|端口|配置文件路径|
|:-----|:-------|:----|
|postgresql|5432|$PGOROOT/conf/postgres-operator/pgo.yaml|
|pgbouncer|5432|$PGOROOT/conf/postgres-operator/pgo.yaml|
|pgbackrest|2022|$PGOROOT/conf/postgres-operator/pgo.yaml|
|postgres-exporter|9187|$PGOROOT/conf/postgres-operator/pgo.yaml|

### 1.3.3 应用端口规划
|应用|端口|配置文件路径|
|:-----|:-------|:----|
|pgbadger|10000|$PGOROOT/conf/postgres-operator/pgo.yaml|

## 1.4 操作步骤说明
### 1.4.1 全新部署一套AntDB集群环境
|操作步骤|操作涉及k8s的节点情况|操作情况说明|操作实现方式|
|:-----|:-------|:-------|:-------|
|1. 调整物理机系统参数|master/slave 节点|一次性工作|手工，建议使用ansible实现批量调整|
|2. 部署k8s环境|master/slave 节点|一次性工作|手工，建议使用kubeadm实现快速部署|
|3. 调整k8s的网络交互模式为ipvs|master 主节点|一次性工作|手工，vim编辑|
|4. 创建工作目录|master/slave 节点|一次性工作|手工，建议使用ansible实现批量调整|
|5. 配置服务端的全局环境变量|master 主节点|一次性工作|手工，vim编辑|
|6. 版本上传/解压|master 主节点|一次性工作|手工，建议使用lrzsz/sftp/ftp|
|7. 配置go运行环境|master 主节点|一次性工作|手工，版本解压即可|
|8. 配置pgo客户端|master 主节点|一次性工作|手工，版本解压即可|
|9. 调整服务端的全局配置文件|master 主节点|一次性工作|手工，vim编辑|
|10. 调整PV相关的配置|master 主节点|一次性工作|手工，vim编辑|
|11. 发布相关镜像|master/slave 节点|一次性工作|crunchydata官方镜像使用shell批量拉取，AntDB相关镜像通过docker load加载|
|12. 初始化operator环境|master 主节点|已通过shell封装，脚本名init_pgo.sh|直接执行shell|
|13. 设置AntDB集群版的部署规模/镜像名称/镜像版本号|master 主节点||手工，vim编辑|
|14. 定制化postgresql.conf相关配置|master 主节点||手工，vim编辑|
|15. 发布AntDB集群版应用至operator环境|master 主节点|已通过shell封装, 脚本名create_antdb.sh|直接执行shell|
|16. 验证AntDB集群版是否满足预期|无要求||手工，建议使用psql命令验证|

### 1.4.2 若希望调整AntDB集群的部署规模，比如增加coordinator节点数量(限测试阶段)
|操作步骤|操作涉及k8s的节点情况|操作情况说明|操作实现方式|
|:-----|:-------|:-------|:-------|
|1. 调整AntDB集群版的部署规模|master 主节点||手工，vim编辑|
|2. 初始化operator环境|master 主节点|已通过shell封装，脚本名init_pgo.sh|直接执行shell|
|3. 清理PV上的数据|master/slave 节点||手工，建议先备份再删除，测试阶段可直接rm删除|
|4. 发布AntDB集群版应用至operator环境|master 主节点|已通过shell封装, 脚本名create_antdb.sh|直接执行shell|
|5. 验证AntDB集群版是否满足预期|无要求||手工，建议使用psql命令验证|

### 1.4.3 若希望调整AntDB集群的部署规模，比如增加coordinator节点数量(生产阶段)
|操作步骤|操作涉及k8s的节点情况|操作情况说明|操作实现方式|
|:-----|:-------|:-------|:-------|
|1. 调整AntDB集群版的部署规模|master 主节点||手工，vim编辑|
|2. 使用clone命令克隆一个新的coordinator节点|master 主节点|调用pgo clone命令|直接调用命令|
|3. 等待新的coordinator节点处于READY状态|master 主节点|调用kubectl get pod命令|直接调用命令|
|4. 更新pgxc_node信息表|master 主节点|已通过shell封装, 脚本名init_pgxc_node.sh|直接执行shell|
|5. 验证AntDB集群版是否满足预期|无要求||手工，建议使用psql命令验证|

## 1.5 镜像说明
|镜像名称|镜像来源|镜像功能说明|备注|
|:-----|:-------|:-------|:-------|
|pgo-apiserver|crunchydata官方|api接口|operator相关镜像|
|pgo-scheduler|crunchydata官方|调度相关|operator相关镜像|
|pgo-event|crunchydata官方|事件通知相关|operator相关镜像|
|postgres-operator|crunchydata官方|观察AntDB集群的运行状态，检测异常后，执行响应的解决措施|operator相关镜像|
|pgo-rmdata|crunchydata官方|销毁pod|operator相关镜像|
|pgo-backrest|crunchydata官方|调用pgbackrest进行数据库备份，支持全部/增量备备和差量备份|operator相关镜像|
|pgo-backrest-repo|crunchydata官方|备份文件所存放的pod|operator相关镜像|
|pgo-backrest-restore|crunchydata官方|调用pgrestore进行数据库恢复|operator相关镜像|
|antdb.cluster.gc-ha|AntDB团队|提供gtm_coord的功能|AntDB集群版组件之一gtm_coord的镜像|
|antdb.cluster.cn-ha|AntDB团队|提供coordinator的功能|AntDB集群版组件之一coordinator的镜像|
|antdb.cluster.db-ha|AntDB团队|提供datanode的功能|AntDB集群版组件之一datanode的镜像|

## 1.6 设计限制说明
* k8s的网络交互模式必须采用ipvs模式
* gtm_coord的pod名称固定为gc-hash(随机数)
* coordinator的pod名称固定为cn[0-9]-hash(随机数)
* datanode的pod名称固定为dn[0-9]-hash(随机数)
* pod内数据库实例的启动端口固定为5432
* cn/dn的pod配套的configmap名称固定为pgo-custom-antdb-config

## 1.7 AntDB部署流程说明
```
前置条件
1. k8s环境已经部署完毕
1. postgres-operator已经完成初始化

AntDB部署流程说明
1. 创建gtm_coord相关的pod
2. gtm_coord的pod处于READY状态后，对外提供该pod的Cluster-IP
3. 确认gtm_coord的pod的Cluster-IP，并改写$PGOROOT/examples/custom-config/postgres-ha.yaml的agtm_host配置信息
4. 创建自定义的configmap，名称固定为pgo-custom-antdb-config
5. 创建datanode相关的pod，其配置信息采用pgo-custom-antdb-config
6. 创建coordinator相关的pod，其配置信息采用pgo-custom-antdb-config
7. 判断antdb_info.txt的num_node中配置的pod数量 及 当前处于READY状态的主POD的数量，若不一致，则一直等待；若一致，继续下面的步骤
8. 采集所有POD的 4个配置信息(POD对应AntDB的组件类型/nodename名称/POD的Cluster-IP/数据库实例端口号)，并保存于本机的/tmp/antdb_info
9. 通过/tmp/antdb_info，生成pgxc_node所需的全部信息
10. 初始化所有coordinator的pgxc_node信息,比较通过kubeget pod 和 通过psql查询当前pgxc_node信息，并总是以前者为准。若psql返回更多的记录，则删除之；若psql返回更少的记录，则新增之；若两者一致，则保持不变。
11. 初始化gtm_coord的pgxc_node信息，原理同上。
```

## 1.8 AntDB提供的安装包目录结构说明
```
pkg
├── antdb.cluster.cn21.0-ha.tar.gz
├── antdb.cluster.db21.0-ha.tar.gz
└── antdb.cluster.gc21.0-ha.tar.gz
shell
├── antdb_info.txt
├── create_antdb.sh
├── init_pgo.sh
└── init_pgxc_node.sh

pkg中是AntDB提供的相关镜像压缩包(docker save方式导出)，shell中是AntDB提供的相关shell脚本/配置文件
```

## 1.9 支持的场景
|场景名称|是否支持|实现方式|场景详细说明|
|:-----|:-------|:-------|:-------|
|POD重启|Y|由于使用POD的Cluster-IP进行通信，因此POD重启不影响pgxc_node或agtm_host|比如手工重启POD，或服务器掉电|
|coordinator缩容|Y|缩容的POD被delete之后，先调低antdb_info.txt的num_node，再手工执行一次init_pgxc_node.sh|比如该coordinator异常，需要从集群中剔除|
|coordinator扩容|Y|新扩容的POD通过pgo clone新增成功后，先调大antdb_info.txt的num_node，再手工执行一次init_pgxc_node.sh||
|datanode扩容|N|||
|datanode扩容|N|||

# 2. 操作部署
## 2.1 调整物理机系统参数
```
1. 调整配置
# vi /etc/sysctl.conf
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1

2. 使配置生效
# sysctl -p
```

## 2.2 部署k8s环境
建议使用kubeadm实现快速部署。具体步骤不在本文探讨范围。

## 2.3 调整k8s的网络交互模式为ipvs
```
1. 添加ipvs相关配置项
# kubectl edit configmap -n kube-system kube-proxy
    ipvs:
      excludeCIDRs: null
      minSyncPeriod: 0s
      scheduler: ""
      strictARP: false
      syncPeriod: 0s
    kind: KubeProxyConfiguration
    metricsBindAddress: "127.0.0.1:10249"

2. 调整网络模式，由iptables改为ipvs
# kubectl edit configmap -n kube-system kube-proxy
    mode: "ipvs"

3. 重启所有的kube-proxy
# kubectl get pod  -n kube-system|grep kube-proxy|awk '{print "kubectl delete pod "$1" -n kube-system"}'|sh
```

## 2.4 配置工作目录
```
1. 创建目录
mkdir -pv /data 

联系AntDB交付团队获取安装部署包：antdb-k8s-deploy.tar.gz
解压缩
tar -xzvf antdb-k8s-deploy.tar.gz -C /data

2. 工作目录结构说明
# pwd
/data/pgo/odev
# tree -L 1 pgo/odev
pgo/odev
├── bin     --go/pgo/expenv 二进制文件所在目录
├── conf    --运行过程中相关的配置文件
├── deploy  --运行过程中部署的相关脚本
├── etc     --k8s rpm-package-key.gpg 
├── examples    --运行的示例配置文件
├── pkg     --提供的AntDB镜像文件，pgo工具源文件
├── pv      --持久化存储相关配置文件，默认使用HostPath存储类型
└── shell   --AntDB提供的脚本文件，为了便于部署AntDB相关的工作而封装的shell脚本

8 directories, 0 files

```

## 2.5 配置服务端的全局环境变量
```
1. 从服务端的envs.sh模块文件追加至$HOME/.bashrc
# cat /data/pgo/odev/examples/envs.sh >> $HOME/.bashrc

2. 根据实际情况调整$HOME/.bashrc(以下只列出需要调整的变量，使用默认值无需调整的不在下列清单中)
export GOPATH=/data/pgo/odev
export PGO_CMD="kubectl"
export PGOROOT=$GOPATH
export PGO_VERSION=4.2.1
#此处的ip是postgres-operator该pod的clusterip，在postgres-operator尚未部署前，默认即可；部署后，则按实际情况调整。
export PGO_APISERVER_URL=https://10.104.231.24:8443   
##AntDB Cluster初始化需要依赖psql命令建议安装postgresql-devel或者使用系统中已有安装的psql命令
export ADB_HOME=/home/antdb/app
export PATH=$ADB_HOME/bin:$PATH

3. 使环境变量生效
# source $HOME/.bashrc
```

## 2.6 验证go运行环境
```
1. 确认go运行环境是否正常
# which go
/data/pgo/odev/bin/go
```

## 2.7 调整存储PV相关的配置
```
1. 调整$PGOROOT/pv/crunchy-pv.json，修改PV映射到k8s Node主机的数据目录路径(请根据实际情况调整路径)

"hostPath": {
        "path": "/data/pv/"
    }

2. 调整$PGOROOT/pv/create-pv.sh，修改创建的PV数量.此处我们创建30个PV
for i in {1..30}

3. k8s Node节点调整持久化存储路径权限
chmod 777 /data/pv/
```

## 2.8 发布相关镜像
### 2.8.1 官方镜像
```
1. 拉取相关镜像并pull到本地
# sh $PGOROOT/bin/pull-from-gcr.sh
```

### 2.8.2 AntDB相关镜像
```
# cd $GOPATH/pkg
# ll antdb.cluster*.tar.gz
-rw------- 1 root root 713056256 Apr  7 14:33 antdb.cluster.cn21.0-ha.tar.gz
-rw------- 1 root root 713067520 Apr  7 14:32 antdb.cluster.db21.0-ha.tar.gz
-rw------- 1 root root 713056768 Apr  7 14:33 antdb.cluster.gc21.0-ha.tar.gz
--设置了镜像版本号之后，使用docker load的方式加载3个镜像
# types=(gc cn db);version="21.0";for type in ${types[@]}; do docker load -i $GOPATH/pkg/antdb.cluster.${type}${version}-ha.tar.gz; done
```

## 2.9 初始化operator环境
```
# cd $GOPATH/shell
# ll
total 24
-rwxr-xr-x 1 root root   385 Apr  8 14:22 antdb_info.txt
-rwxr-xr-x 1 root root  3567 Apr  8 14:22 create_antdb.sh
-rwxr-xr-x 1 root root   798 Apr  8 14:22 init_pgo.sh
-rwxr-xr-x 1 root root 10880 Apr  8 14:22 init_pgxc_node.sh

--执行初始化operator环境的shell脚本(期间有一次交互，让你输入Y/N，输入Y即可)
# init_pgo.sh

--上述脚本执行期间，会修改$HOME/.bashrc的$PGO_APISERVER_URL环境变量，需要手工使环境变量生效
--使环境变量生效
# source ~/.bashrc

--验证operator部署成功
--正常返回CLUSTER-IP及端口信息
# kubectl get service postgres-operator -n pgo
NAME                TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
postgres-operator   ClusterIP   10.110.92.107   <none>        8443/TCP,4171/TCP,4150/TCP   3m39s
--postgres-operator涉及了4个镜像，分别启动了4个POD，全部显示为READY状态
# kubectl get pod --selector=name=postgres-operator -n pgo
NAME                                 READY   STATUS    RESTARTS   AGE
postgres-operator-576cc8f865-wbn56   4/4     Running   0          3m45s
```

## 2.10 设置AntDB集群版的部署规模/镜像名称/镜像版本号
```
# cd $GOPATH/shell
# vim antdb_info.txt 

#gtm_coord/coordinator/datanode,下列所有数组均按该顺序设置

#节点数量，根据实际情况调整，gtm_coord固定为1，coordinator/datanode数量按需调整
num_node=(1 2 3)

#各组件使用的镜像相关信息
#镜像前缀，默认即可
image_prefix="crunchydata"
#镜像名称，默认即可
image_name=("antdb.cluster.gc-ha" "antdb.cluster.cn-ha" "antdb.cluster.db-ha")
#镜像版本号，根据实际情况调整
image_version=("21.0" "21.0" "21.0")

#k8s 使用的namespace名称，默认即可
namespace="pgouser1"
```

## 2.11 定制化postgresql.conf相关配置
```
1. 调整配置文件相关
# vim $PGOROOT/examples/custom-config/postgres-ha.yaml
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
        shared_preload_libraries: pg_stat_statements.so
        log_directory: pg_log
        log_destination: csvlog
        logging_collector: on
        log_min_messages: info
        agtm_host: '10.103.25.232'
        agtm_port: 5432
        max_prepared_transactions: 1000
postgresql:
  pg_hba:
    - local all postgres peer
    - local all crunchyadm peer
    - host replication primaryuser 0.0.0.0/0 md5
    - host all primaryuser 0.0.0.0/0 reject
    - host all postgres 0.0.0.0/0 trust
    - host all testuser1 0.0.0.0/0 md5
    - host all testuser2 0.0.0.0/0 md5


其中：
必须添加的3个配置项，注意格式，ip地址和port默认即可，max_prepared_transactions按需配置，默认1000也足够了。
        agtm_host: '10.103.25.232' ##该IP地址会在operator初始化GC节点的时候由程序自动替换为实际GC的IP地址，初始输入任意IP即可
        agtm_port: 5432 ##GC的端口
        max_prepared_transactions: 1000
必须调整的1个配置项，将pg_audit.so删除。删除的原因同setup.sql的情况说明。
        shared_preload_libraries: pg_stat_statements.so
其他parameters相关参数，结合实际情况配置
pg_hba结合实际情况配置
```

## 2.12 发布AntDB集群版应用至operator环境
```
# cd $GOPATH/shell
# create_antdb.sh

--上述脚本执行期间，打印的日志信息如下
created Pgcluster gc
workflow id 1355e2e5-f8e4-417d-bec6-955e533f7fc6
No resources found in pgouser1 namespace.
cluster gc is running,ip is :10.99.123.72
Wed Apr  8 14:52:55 CST 2020 INFO: PGO_NAMESPACE=pgouser1
Error from server (NotFound): configmaps "pgo-custom-antdb-config" not found
configmap/pgo-custom-antdb-config created
created Pgcluster dn1
workflow id e330296f-69fe-4941-8c0f-88a4d22456ac
created Pgcluster dn2
workflow id 75b3b077-9a40-40cd-b946-660e0d78ac18
created Pgcluster dn3
workflow id 1e7aa5dd-d832-4203-a2db-d4af3fc96a3d
created Pgcluster cn1
workflow id 53a1b350-f73b-4b86-bea3-d3d0d022e7b5
created Pgcluster cn2
workflow id 1555957d-f6af-4993-b3d7-213ea58133fa
total pod num is 6,now running or ready pod num is 0,keep waiting...
================================================================================
dn1-6dbc9b745b-v8t7g 0/1 Running
dn2-6f985d678-q774q 0/1 Running
gc-5ccf496dd6-mz7ll 0/1 Running
================================================================================
total pod num is 6,now running or ready pod num is 1,keep waiting...
================================================================================
dn1-6dbc9b745b-v8t7g 0/1 Running
dn2-6f985d678-q774q 0/1 Running
dn3-5d77dbc59d-lnr5l 0/1 Running
gc-5ccf496dd6-mz7ll 1/1 Running
================================================================================
total pod num is 6,now running or ready pod num is 2,keep waiting...
================================================================================
cn1-58dffb454d-wr26j 0/1 Running
cn2-6b888cb78f-gtm52 0/1 ContainerCreating dn1-6dbc9b745b-v8t7g 1/1 Running
dn2-6f985d678-q774q 0/1 Running
dn3-5d77dbc59d-lnr5l 0/1 Running
gc-5ccf496dd6-mz7ll 1/1 Running
================================================================================
total pod num is 6,now running or ready pod num is 3,keep waiting...
================================================================================
cn1-58dffb454d-wr26j 0/1 Running
cn2-6b888cb78f-gtm52 0/1 Running
dn1-6dbc9b745b-v8t7g 1/1 Running
dn2-6f985d678-q774q 1/1 Running
dn3-5d77dbc59d-lnr5l 0/1 Running
gc-5ccf496dd6-mz7ll 1/1 Running
================================================================================
total pod num is 6,now running or ready pod num is 4,keep waiting...
================================================================================
cn1-58dffb454d-wr26j 0/1 Running
cn2-6b888cb78f-gtm52 0/1 Running
dn1-6dbc9b745b-v8t7g 1/1 Running
dn2-6f985d678-q774q 1/1 Running
dn3-5d77dbc59d-lnr5l 1/1 Running
gc-5ccf496dd6-mz7ll 1/1 Running
================================================================================
total pod num is 6,now running or ready pod num is 5,keep waiting...
================================================================================
cn1-58dffb454d-wr26j 1/1 Running
cn2-6b888cb78f-gtm52 0/1 Running
dn1-6dbc9b745b-v8t7g 1/1 Running
dn2-6f985d678-q774q 1/1 Running
dn3-5d77dbc59d-lnr5l 1/1 Running
gc-5ccf496dd6-mz7ll 1/1 Running
================================================================================
total pod num is 6,now running or ready pod num is 5,keep waiting...
================================================================================
cn1-58dffb454d-wr26j 1/1 Running
cn2-6b888cb78f-gtm52 0/1 Running
dn1-6dbc9b745b-v8t7g 1/1 Running
dn2-6f985d678-q774q 1/1 Running
dn3-5d77dbc59d-lnr5l 1/1 Running
gc-5ccf496dd6-mz7ll 1/1 Running
================================================================================
total pod num is 6,now running or ready pod num is 5,keep waiting...
================================================================================
cn1-58dffb454d-wr26j 1/1 Running
cn2-6b888cb78f-gtm52 0/1 Running
dn1-6dbc9b745b-v8t7g 1/1 Running
dn2-6f985d678-q774q 1/1 Running
dn3-5d77dbc59d-lnr5l 1/1 Running
gc-5ccf496dd6-mz7ll 1/1 Running
================================================================================
all pod is running and ready,begin to init pgxc_node .
所有pod的信息收集于本机的该目录：/tmp/antdb_info
coordinator cn1 10.100.165.65 5432
coordinator cn2 10.107.164.70 5432
datanode dn1 10.98.53.160 5432
datanode dn2 10.100.171.135 5432
datanode dn3 10.108.50.74 5432
gtm_coord gc 10.99.123.72 5432
ALTER NODE
CREATE NODE
CREATE NODE
CREATE NODE
CREATE NODE
CREATE NODE
DELETE 0
 pgxc_pool_reload 
------------------
 t
(1 row)

CREATE NODE
ALTER NODE
CREATE NODE
CREATE NODE
CREATE NODE
CREATE NODE
DELETE 0
 pgxc_pool_reload 
------------------
 t
(1 row)

ALTER NODE
CREATE NODE
CREATE NODE
CREATE NODE
CREATE NODE
CREATE NODE
DELETE 0
 pgxc_pool_reload 
------------------
 t
(1 row)
```

## 2.13 验证AntDB集群运行正常
```
1. 查看主要POD的状态，全部处于Running且READY状态(其他辅助POD，比如备份，通过grep -V 排除掉了，否则展示太多，容易看花眼)
# kubectl get pod -n pgouser1|grep -Ev '[a-z A-Z 0-9]+[-][a-z A-Z 0-9]+[-][a-z A-Z 0-9]+[-][a-z A-Z 0-9]+'
NAME                                        READY   STATUS      RESTARTS   AGE
cn1-58dffb454d-wr26j                        1/1     Running     0          10m
cn2-6b888cb78f-gtm52                        1/1     Running     0          10m
dn1-6dbc9b745b-v8t7g                        1/1     Running     0          11m
dn2-6f985d678-q774q                         1/1     Running     0          10m
dn3-5d77dbc59d-lnr5l                        1/1     Running     0          10m
gc-5ccf496dd6-mz7ll                         1/1     Running     0          11m

2. 查看主要pod的业务状态，展示其ClusterIP及端口信息
# kubectl get svc -n pgouser1|grep -Ev '[a-z A-Z 0-9]+[-][a-z A-Z 0-9]+[-][a-z A-Z 0-9]+[-][a-z A-Z 0-9]+'
NAME                       TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                                         AGE
cn1                        ClusterIP   10.100.165.65    <none>        5432/TCP,10000/TCP,2022/TCP,9187/TCP,8009/TCP   13m
cn2                        ClusterIP   10.107.164.70    <none>        5432/TCP,10000/TCP,2022/TCP,9187/TCP,8009/TCP   13m
dn1                        ClusterIP   10.98.53.160     <none>        5432/TCP,10000/TCP,2022/TCP,9187/TCP,8009/TCP   13m
dn2                        ClusterIP   10.100.171.135   <none>        5432/TCP,10000/TCP,2022/TCP,9187/TCP,8009/TCP   13m
dn3                        ClusterIP   10.108.50.74     <none>        5432/TCP,10000/TCP,2022/TCP,9187/TCP,8009/TCP   13m
gc                         ClusterIP   10.99.123.72     <none>        5432/TCP,10000/TCP,2022/TCP,9187/TCP,8009/TCP   13m

3. 通过psql登录gtm_coord，查看pgxc_node表及创建测试表
# psql -p 5432 -d postgres -U postgres -h 10.99.123.72 
psql (11.5, server 11.6)
Type "help" for help.

postgres=# select version();
                                                          version                                                          
---------------------------------------------------------------------------------------------------------------------------
 PostgreSQL 11.6 ADB 5.0.0 a8a0374 on x86_64-pc-linux-gnu, compiled by gcc (GCC) 4.8.5 20150623 (Red Hat 4.8.5-36), 64-bit
(1 row)

postgres=# select * from pgxc_node;
 node_name | node_type | node_port |   node_host    | nodeis_primary | nodeis_preferred | nodeis_gtm |   node_id   | node_master_oid 
-----------+-----------+-----------+----------------+----------------+------------------+------------+-------------+-----------------
 gc        | C         |      5432 | 10.99.123.72   | f              | f                | t          |   196570402 |               0
 dn1       | D         |      5432 | 10.98.53.160   | t              | f                | f          |  -560021589 |               0
 dn2       | D         |      5432 | 10.100.171.135 | f              | f                | f          |   352366662 |               0
 dn3       | D         |      5432 | 10.108.50.74   | f              | f                | f          |  -700122826 |               0
 cn1       | C         |      5432 | 10.100.165.65  | f              | f                | f          | -1178713634 |               0
 cn2       | C         |      5432 | 10.107.164.70  | f              | f                | f          | -1923125220 |               0
(6 rows)

postgres=# create table test01 (id int,name text);
CREATE TABLE

postgres=# insert into test01 select id,md5(id::text) from generate_series(1,10000) id;
INSERT 0 10000

postgres=# select b.node_name,count(*) from test01 a,pgxc_node b where a.xc_node_id = b.node_id group by b.node_name;
 node_name | count 
-----------+-------
 dn1       |  3249
 dn2       |  3361
 dn3       |  3390
(3 rows)

postgres=#

4. 通过psql登录coordinator，查看pgxc_node表及测试表数据
# psql -p 5432 -d postgres -U postgres -h 10.100.165.65
psql (11.5, server 11.6)
Type "help" for help.

postgres=# select version();
                                                          version                                                          
---------------------------------------------------------------------------------------------------------------------------
 PostgreSQL 11.6 ADB 5.0.0 a8a0374 on x86_64-pc-linux-gnu, compiled by gcc (GCC) 4.8.5 20150623 (Red Hat 4.8.5-36), 64-bit
(1 row)

postgres=# select * from pgxc_node;
 node_name | node_type | node_port |   node_host    | nodeis_primary | nodeis_preferred | nodeis_gtm |   node_id   | node_master_oid 
-----------+-----------+-----------+----------------+----------------+------------------+------------+-------------+-----------------
 cn1       | C         |      5432 | 10.100.165.65  | f              | f                | f          | -1178713634 |               0
 cn2       | C         |      5432 | 10.107.164.70  | f              | f                | f          | -1923125220 |               0
 dn1       | D         |      5432 | 10.98.53.160   | t              | f                | f          |  -560021589 |               0
 dn2       | D         |      5432 | 10.100.171.135 | f              | f                | f          |   352366662 |               0
 dn3       | D         |      5432 | 10.108.50.74   | f              | f                | f          |  -700122826 |               0
 gc        | C         |      5432 | 10.99.123.72   | f              | f                | t          |   196570402 |               0
(6 rows)

postgres=# select count(*) from test01;
 count 
-------
 10000
(1 row)

postgres=# select b.node_name,count(*) from test01 a,pgxc_node b where a.xc_node_id = b.node_id group by b.node_name;
 node_name | count 
-----------+-------
 dn1       |  3249
 dn2       |  3361
 dn3       |  3390
(3 rows)

postgres=# 

5. 查看当前所有pod的状态
# kubectl get pod -n pgouser1
NAME                                        READY   STATUS      RESTARTS   AGE
backrest-backup-cn1-mkqt5                   0/1     Completed   0          21m
backrest-backup-cn2-5bb7l                   0/1     Completed   0          21m
backrest-backup-dn1-h5m4d                   0/1     Completed   0          22m
backrest-backup-dn2-hvrqr                   0/1     Completed   0          22m
backrest-backup-dn3-jkfxg                   0/1     Completed   0          22m
backrest-backup-gc-8tcqw                    0/1     Completed   0          22m
cn1-58dffb454d-wr26j                        1/1     Running     0          22m
cn1-backrest-shared-repo-b476446d5-5nf9v    1/1     Running     0          22m
cn1-stanza-create-5r2tc                     0/1     Completed   0          21m
cn2-6b888cb78f-gtm52                        1/1     Running     0          22m
cn2-backrest-shared-repo-8dbcb4574-cgjrb    1/1     Running     0          22m
cn2-stanza-create-vwgsf                     0/1     Completed   0          21m
dn1-6dbc9b745b-v8t7g                        1/1     Running     0          22m
dn1-backrest-shared-repo-6c986bd54b-fkcgt   1/1     Running     0          22m
dn1-stanza-create-8pk7m                     0/1     Completed   0          22m
dn2-6f985d678-q774q                         1/1     Running     0          22m
dn2-backrest-shared-repo-74c6567c57-l5kkw   1/1     Running     0          22m
dn2-stanza-create-ldbcq                     0/1     Completed   0          22m
dn3-5d77dbc59d-lnr5l                        1/1     Running     0          22m
dn3-backrest-shared-repo-787b9b9fbd-9zm9p   1/1     Running     0          22m
dn3-stanza-create-bfhn6                     0/1     Completed   0          22m
gc-5ccf496dd6-mz7ll                         1/1     Running     0          23m
gc-backrest-shared-repo-69dc8fb5c-pljqw     1/1     Running     0          23m
gc-stanza-create-x9g2c                      0/1     Completed   0          22m
```

# 3. 验证pod重启之后，AntDB集群不需要任何调整，仍可继续正常使用，且数据正确
此处以重启gtm_coord为例，重启coordinator/datanode的验证过程类似，不赘述。
```
1. pod重启前，即当前数据库状态
# kubectl get svc -n pgouser1|grep -Ev '[a-z A-Z 0-9]+[-][a-z A-Z 0-9]+[-][a-z A-Z 0-9]+[-][a-z A-Z 0-9]+'
NAME                       TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                                         AGE
cn1                        ClusterIP   10.100.165.65    <none>        5432/TCP,10000/TCP,2022/TCP,9187/TCP,8009/TCP   29m
cn2                        ClusterIP   10.107.164.70    <none>        5432/TCP,10000/TCP,2022/TCP,9187/TCP,8009/TCP   29m
dn1                        ClusterIP   10.98.53.160     <none>        5432/TCP,10000/TCP,2022/TCP,9187/TCP,8009/TCP   29m
dn2                        ClusterIP   10.100.171.135   <none>        5432/TCP,10000/TCP,2022/TCP,9187/TCP,8009/TCP   29m
dn3                        ClusterIP   10.108.50.74     <none>        5432/TCP,10000/TCP,2022/TCP,9187/TCP,8009/TCP   29m
gc                         ClusterIP   10.99.123.72     <none>        5432/TCP,10000/TCP,2022/TCP,9187/TCP,8009/TCP   29m
# kubectl get pod -n pgouser1|grep -Ev '[a-z A-Z 0-9]+[-][a-z A-Z 0-9]+[-][a-z A-Z 0-9]+[-][a-z A-Z 0-9]+'
NAME                                        READY   STATUS      RESTARTS   AGE
cn1-58dffb454d-wr26j                        1/1     Running     0          29m
cn2-6b888cb78f-gtm52                        1/1     Running     0          29m
dn1-6dbc9b745b-v8t7g                        1/1     Running     0          29m
dn2-6f985d678-q774q                         1/1     Running     0          29m
dn3-5d77dbc59d-lnr5l                        1/1     Running     0          29m
gc-5ccf496dd6-mz7ll                         1/1     Running     0          29m
# psql -p 5432 -d postgres -U postgres -h 10.99.123.72
psql (11.5, server 11.6)
Type "help" for help.

postgres=# select * from pgxc_node;
 node_name | node_type | node_port |   node_host    | nodeis_primary | nodeis_preferred | nodeis_gtm |   node_id   | node_master_oid 
-----------+-----------+-----------+----------------+----------------+------------------+------------+-------------+-----------------
 gc        | C         |      5432 | 10.99.123.72   | f              | f                | t          |   196570402 |               0
 dn1       | D         |      5432 | 10.98.53.160   | t              | f                | f          |  -560021589 |               0
 dn2       | D         |      5432 | 10.100.171.135 | f              | f                | f          |   352366662 |               0
 dn3       | D         |      5432 | 10.108.50.74   | f              | f                | f          |  -700122826 |               0
 cn1       | C         |      5432 | 10.100.165.65  | f              | f                | f          | -1178713634 |               0
 cn2       | C         |      5432 | 10.107.164.70  | f              | f                | f          | -1923125220 |               0
(6 rows)

postgres=# select count(*) from test01;
 count 
-------
 10000
(1 row)

postgres=# select b.node_name,count(*) from test01 a,pgxc_node b where a.xc_node_id = b.node_id group by b.node_name;
 node_name | count 
-----------+-------
 dn1       |  3249
 dn2       |  3361
 dn3       |  3390
(3 rows)


2. 重启pod
# kubectl delete pod gc-5ccf496dd6-mz7ll -n pgouser1
pod "gc-5ccf496dd6-mz7ll" deleted

3. 等待几秒钟，确认信的pod已Running，且处于READY状态
# kubectl get pod -n pgouser1|grep -Ev '[a-z A-Z 0-9]+[-][a-z A-Z 0-9]+[-][a-z A-Z 0-9]+[-][a-z A-Z 0-9]+'
NAME                                        READY   STATUS      RESTARTS   AGE
cn1-58dffb454d-wr26j                        1/1     Running     0          30m
cn2-6b888cb78f-gtm52                        1/1     Running     0          30m
dn1-6dbc9b745b-v8t7g                        1/1     Running     0          30m
dn2-6f985d678-q774q                         1/1     Running     0          30m
dn3-5d77dbc59d-lnr5l                        1/1     Running     0          30m
gc-5ccf496dd6-vhpmt                         1/1     Running     0          38s

gc所在的pod由原gc-5ccf496dd6-mz7ll更新为gc-5ccf496dd6-vhpmt，Runing并已处于READY状态

# kubectl get svc -n pgouser1|grep -Ev '[a-z A-Z 0-9]+[-][a-z A-Z 0-9]+[-][a-z A-Z 0-9]+[-][a-z A-Z 0-9]+'
NAME                       TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                                         AGE
cn1                        ClusterIP   10.100.165.65    <none>        5432/TCP,10000/TCP,2022/TCP,9187/TCP,8009/TCP   33m
cn2                        ClusterIP   10.107.164.70    <none>        5432/TCP,10000/TCP,2022/TCP,9187/TCP,8009/TCP   33m
dn1                        ClusterIP   10.98.53.160     <none>        5432/TCP,10000/TCP,2022/TCP,9187/TCP,8009/TCP   33m
dn2                        ClusterIP   10.100.171.135   <none>        5432/TCP,10000/TCP,2022/TCP,9187/TCP,8009/TCP   33m
dn3                        ClusterIP   10.108.50.74     <none>        5432/TCP,10000/TCP,2022/TCP,9187/TCP,8009/TCP   33m
gc                         ClusterIP   10.99.123.72     <none>        5432/TCP,10000/TCP,2022/TCP,9187/TCP,8009/TCP   33m

ClusterIP在POD重启前后，保持不变

4. 检查AntDB集群状态及数据的正确性
# psql -p 5432 -d postgres -U postgres -h 10.99.123.72
psql (11.5, server 11.6)
Type "help" for help.

postgres=# select * from pgxc_node;
 node_name | node_type | node_port |   node_host    | nodeis_primary | nodeis_preferred | nodeis_gtm |   node_id   | node_master_oid 
-----------+-----------+-----------+----------------+----------------+------------------+------------+-------------+-----------------
 gc        | C         |      5432 | 10.99.123.72   | f              | f                | t          |   196570402 |               0
 dn1       | D         |      5432 | 10.98.53.160   | t              | f                | f          |  -560021589 |               0
 dn2       | D         |      5432 | 10.100.171.135 | f              | f                | f          |   352366662 |               0
 dn3       | D         |      5432 | 10.108.50.74   | f              | f                | f          |  -700122826 |               0
 cn1       | C         |      5432 | 10.100.165.65  | f              | f                | f          | -1178713634 |               0
 cn2       | C         |      5432 | 10.107.164.70  | f              | f                | f          | -1923125220 |               0
(6 rows)

postgres=# select count(*) from test01;
 count 
-------
 10000
(1 row)

postgres=# select b.node_name,count(*) from test01 a,pgxc_node b where a.xc_node_id = b.node_id group by b.node_name;
 node_name | count 
-----------+-------
 dn1       |  3249
 dn2       |  3361
 dn3       |  3390
(3 rows)

```

# 遗留问题
## 1. 目前PV都是统一大小。但生产环境，各组件所需的PV容量差异非常大。

**问题现象**
```
xxx
```

**错误原因** xxx

**解决方式** 

xxx 

# 总结

# 参考
AntDB QQ群号：496464280

[AntDB github链接](https://github.com/ADBSQL)