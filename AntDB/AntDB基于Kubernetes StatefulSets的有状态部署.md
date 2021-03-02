# AntDB-基于Kubernetes StatefulSets有状态部署
***
本文主要探讨AntDB基于Kubernetes通过StatefulSets实现有状态部署的实施方案。
通过本文实现下述功能：
* AntDB 镜像制作
* AntDB 分布式数据库部署
* 验证过程中的问题分析处理

***

# 版本说明

|kubernetes版本|1.17+||
|:-----|:-------|:-------|
|docker版本|19.03.7||
|AntDB版本|5.0 d4faff7|集群版|
|容器内OS版本|centos 7.7.1908||

# 术语说明
```
AntDB节点类型说明：
gc：全局事务管理主节点
gcs：全局事务管理备节点
cn：协调节点（计算节点）
dn：数据存储主节点
ds：数据存储备节点
mgr：集群管理节点
```

# 需要准备的镜像

**OS相关镜像：**
docker pull docker.io/centos:7.7.1908

**AntDB相关镜像：**
制作AntDB 5.0自己的dockerfile

```
FROM centos:7.7.1908
ENV LC_ALL en_US.utf-8
ENV LANG en_US.utf-8
RUN yum clean all && yum makecache
RUN yum install -y perl-ExtUtils-Embed flex bison readline-devel zlib-devel openssl-devel pam-devel libxml2-devel libxslt-devel openldap-devel python-devel libssh2-devel
RUN yum -y install expect epel-release
RUN yum -y install python-psycopg2 python2-argh python2-argcomplete python-dateutil
RUN rpm --rebuilddb && yum install -y sg3_utils lrzsz vim which make wget gcc rsync net-tools unzip dos2unix strace gdb sudo
RUN rpm --rebuilddb && yum -y install openssh-server openssh-clients
RUN sed -ri 's/session required pam_loginuid.so/#session required pam_loginuid.so/g' /etc/pam.d/sshd
RUN sed -i 's/UsePAM yes/UsePAM no/g' /etc/ssh/sshd_config
RUN sed -i "s/#UsePrivilegeSeparation.*/UsePrivilegeSeparation no/g" /etc/ssh/sshd_config
RUN ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key
RUN ssh-keygen -t rsa -f /etc/ssh/ssh_host_ecdsa_key
RUN ssh-keygen -t rsa -f /etc/ssh/ssh_host_ed25519_key
RUN sed -i 's/PermitEmptyPasswords yes/PermitEmptyPasswords no /' /etc/ssh/sshd_config && \
sed -i 's/PermitRootLogin without-password/PermitRootLogin yes /' /etc/ssh/sshd_config && \
echo " StrictHostKeyChecking no" >> /etc/ssh/ssh_config && \
echo " UserKnownHostsFile /dev/null" >> /etc/ssh/ssh_config
ADD adb-5.0.d4faff7.tar.gz /tmp/
ADD adb-barman-master.tar.gz /tmp/
ADD node_exporter.tar.gz /tmp/
ADD postgres-exporter2.tar.gz /tmp/
RUN rpm -ivh /tmp/antdb.cluster-5.0.d4faff7-centos7.6.rpm && rpm -ivh /tmp/antdb.cluster-debuginfo-5.0.d4faff7-centos7.6.rpm
RUN echo "root:9b8b2e4e23" | chpasswd
RUN groupadd antdb && useradd -g antdb antdb && mkdir -p /home/antdb/data/shell && chown -R antdb:antdb /home/antdb/data && chmod -R 777 /home/antdb
RUN echo "antdb:2b8b2e4e13" | chpasswd
RUN chown -R antdb:antdb /opt/app/antdb && chmod -R 755 /opt/app/antdb
RUN sed -i '/^antdb          ALL=(ALL)       NOPASSWD: ALL$/d' /etc/sudoers && sed -i '$a\antdb          ALL=(ALL)       NOPASSWD: ALL' /etc/sudoers
RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
RUN mv /tmp/adb-barman-master /home/antdb && chown -R antdb:antdb /home/antdb/adb-barman-master
RUN mv /tmp/node_exporter /home/antdb && chown -R antdb:antdb /home/antdb/node_exporter
RUN mv /tmp/postgres-exporter2 /home/antdb && chown -R antdb:antdb /home/antdb/postgres-exporter2
USER antdb
RUN ssh-keygen -t rsa -f ~/.ssh/id_rsa -P '' && cat /home/antdb/.ssh/id_rsa.pub >> /home/antdb/.ssh/authorized_keys
ENV ADB_HOME /opt/app/antdb
ENV PATH $ADB_HOME/bin:$PATH
ENV LD_LIBRARY_PATH=$ADB_HOME/lib:$LD_LIBRARY_PATH
ENV PARAMS=""
ENV PGXC_NODE_NAME=""
ENV NODE_NAMESPACE=""
ADD start.sh /home/antdb/data/shell
ADD start_ne.sh /home/antdb/data/shell
ADD update-antdb.sh /home/antdb/data/shell
ADD install-barman.sh /home/antdb/data/shell
#ADD init_pgxc_node.sh /home/antdb/data/shell
RUN sudo chmod 755 /home/antdb/data/shell/*.sh
RUN /home/antdb/data/shell/install-barman.sh
ENV PATH $ADB_HOME/bin:/home/antdb/.local/bin:$PATH
CMD echo $PARAMS > /tmp/params.txt && echo $PGXC_NODE_NAME > /dev/null && echo $NODE_NAMESPACE > /dev/null && /home/antdb/data/shell/start.sh && /home/antdb/data/shell/start_ne.sh && tail -f /tmp/params.txt
```

# 构建AntDB镜像

## 1. 构建镜像
```
docker build -t asiainfo/antdb50:1.1 -f 5.dockerfile .
```

## 2. 导入镜像
```
docker load --input /root/asiainfo_antdb50_1.1.tar 
Loaded image: asiainfo/antdb50:1.1
```

## 3. 验证镜像
```
docker image ls|grep asiainfo/antdb50
asiainfo/antdb50                                          1.1                 41294328e597        9 days ago          1.45 GB
```

#AntDB集群部署

## 1. 环境准备

### 存储准备
```
AntDB k8s集群版使用本地hostpath作为持久化存储；
默认存储路径为：
hostPath:
    path: /data/pv
容量为：
capacity:
    storage: 10Gi
在部署AntDB集群的时候建议根据实际存储路径修改此项配置（路径和容量）；
在k8s集群node节点中提前创建该存储路径并授予权限777；

注意：实际所需存储容量请按照预估的数据存储量设置并建议保留一定的冗余
```

## 2. 资源设置
```
AntDB集群节点包含：gc、gcs、cn、dn、ds、mgr六种类型；
默认资源需求：
gc:
    resources:
          limits:
            cpu: 2
            memory: 1G
          requests:
            cpu: 1
            memory: 500M
gcs:
    resources:
          limits:
            cpu: 2
            memory: 1G
          requests:
            cpu: 1
            memory: 500M
cn:
    resources:
          limits:
            cpu: 2
            memory: 512M
          requests:
            cpu: 1
            memory: 256M
dn:
    resources:
          limits:
            cpu: 2
            memory: 1G
          requests:
            cpu: 1
            memory: 500M
ds:
    resources:
          limits:
            cpu: 2
            memory: 1G
          requests:
            cpu: 1
            memory: 500M
mgr:            
    resources:
          limits:
            cpu: 2
            memory: 1G
          requests:
            cpu: 1
            memory: 500M
            
部署所需资源请按照需求自行调整，调整文件如下：
adb-cluster-cn.yaml
adb-cluster-dn.yaml
adb-cluster-ds.yaml
adb-cluster-gcs.yaml
adb-cluster-gc.yaml
adb-cluster-mgr.yaml
```

## 3. 开始部署
```
deploy-antdb.sh
expand-antdb.sh
init_mgr_node.sh
mgr_expand.sh
mgr_init.sh
rm-antdb.sh
update-antdb.sh
full-update-antdb.sh
update_all_node.sh

在k8s集群中部署过kubectl命令的节点执行
./deploy-antdb.sh antdb
注：antdb是AntDB集群部署的namespace名称
```

## 4. 增加节点
```
增加coordinator节点：
修改adb-cluster-cn.yaml中的replicas: 1内容，修改为需要的节点数；
在k8s集群中部署过kubectl命令的节点执行:
kubectl apply -f adb-cluster-cn.yaml -n antdb
./expand-antdb.sh antdb cn

增加datanode节点（datanode主从节点必须同时添加，不允许只添加主或者从节点）：
修改adb-cluster-dn.yaml和adb-cluster-ds.yaml中的replicas: 2内容，修改为需要的节点数；
在k8s集群中部署过kubectl命令的节点执行:
kubectl apply -f adb-cluster-dn.yaml -n antdb
kubectl apply -f adb-cluster-ds.yaml -n antdb
./expand-antdb.sh antdb dn

```
## 5. 所有POD节点IP变更
```
当AntDB集群所在k8s平台需要维护，所有的节点使用的Pod重启后，所有数据库节点IP地址都会变更；
此时AntDB集群实际存储的节点IP信息和实际Pod的IP信息不一致，需要执行如下变更操作：
./full-update-antdb.sh antdb
注：antdb是AntDB集群部署的namespace名称
```

## 6. 删除AntDB集群
```
提供AntDB集群删除功能，使用如下命令执行集群删除操作：
./rm-antdb.sh antdb
注：antdb是AntDB集群部署的namespace名称

注意：集群删除后，AntDB所有数据均会被删除，k8s资源会被释放，请确认后操作；
```

## 7. AntDB prometheus监控
```
AntDB集群所有pod节点默认安装node_exporter和postgres_exporter;
node_exporter容器默认启动，端口为9100：
[antdb@mgr-0 /]$ ps -ef|grep node_exporter
antdb        58      1  0 Sep01 ?        00:07:37 /home/antdb/node_exporter/node_exporter --web.listen-address=:9100

AntDB集群实例监控使用postgres_exporter
部署目录：/home/antdb/postgres-exporter2
使用方法：
进入部署目录，按照格式修改antdb_master_list.txt和antdb_slave_list.txt文件；
执行脚本：start_antdb_master_monitor.sh和start_antdb_slave_monitor.sh
```

# 实现和问题总结：

## 1. POD重启IP变动如何处理
```
目前AntDB版本暂时不支持通过域名的方式存储集群主机相关的IP信息；
这样就面临一个问题：当集群中某个节点的pod因为某种原因重启后，pod的IP信息会改变，但是集群中存储的该节点信息还是旧的IP，
此时需要更新整个集群中此pod的IP信息；

那么当pod重新启动后，如何触发IP地址更新的动作呢？
在k8s中，当创建资源对象时，可以使用lifecycle来管理容器在运行前和关闭前的一些动作。

lifecycle有两种回调函数：
--PostStart：容器创建成功后，运行前的任务，用于资源部署、环境准备等。
--PreStop：在容器被终止前的任务，用于优雅关闭应用程序、通知其他系统等等。

我们可以通过使用PostStart在pod重启后，完成重启前运行一些任务，譬如：更新AntDB集群中此pod节点的IP地址信息；

具体实现：
将AntDB各组件IP更新逻辑通过shell脚本封装，并存放于容器镜像中；
在部署的AntDB各个节点组件的StatefulSets文件中增加如下内容：
        lifecycle:
          postStart:
            exec:
              command:
                - "/bin/sh"
                - "/home/antdb/data/shell/update-antdb.sh"
                
这样即可实现不论何种组件的pod出现重启的情况下能够完成集群信息的更新同步；

```

## 2. 设置亲和性
```
在实际物理机环境部署中，AntDB集群中的主从节点都是需要跨物理节点部署，一组主从节点不会同时存在于同一个物理机器上，
避免了主机故障导致主从节点同时不可用，影响高可用切换；
在k8s环境中同样面临类似的问题，集群中的GTMC和DataNode主从节点不能部署在同一个node节点主机上，那么如何实现这样的功能呢？
在k8s中有如下运行时调度策略可以实现：包括nodeAffinity（主机亲和性），podAffinity（POD亲和性）以及podAntiAffinity（POD反亲和性）。
--nodeAffinity 主要解决POD要部署在哪些主机，以及POD不能部署在哪些主机上的问题，处理的是POD和主机之间的关系。
--podAffinity 主要解决POD可以和哪些POD部署在同一个拓扑域中的问题（拓扑域用主机标签实现，可以是单个主机，也可以是多个主机组成的cluster、zone等。）
--podAntiAffinity主要解决POD不能和哪些POD部署在同一个拓扑域中的问题。它们处理的是Kubernetes集群内部POD和POD之间的关系。

我们通过分别设置部署的GTMC Master和Slave、DataNode Master和Slave pod的podAntiAffinity，实现Master和Slave节点之间的互斥，部署在不同的节点上；
```
### GTMC
```
Master：
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - gtmcs
              topologyKey: kubernetes.io/hostname
              
Slave：
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - gtmc
              topologyKey: kubernetes.io/hostname
```
### DataNode
```
Mater：
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - ds
            topologyKey: kubernetes.io/hostname

Slave：
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - dn
            topologyKey: kubernetes.io/hostname
```