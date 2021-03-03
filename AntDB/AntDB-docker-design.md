
# AntDB容器化设计概述
***
本文主要探讨AntDB基于docker的虚拟化分布式数据库实现。

通过本文实现下述功能：
* 容器主机名固化
* 容器ip防漂移
* 存储持久化
* AntDB集群动态参数如何传入docker
* AntDB基于docker的虚拟化分布式数据库实现
***

# 环境介绍
|操作系统|centos7.4|
|:-----|:-------|
|docker版本|1.13|
|AntDB版本|4.0|
|AntDB架构|2C2D， 每物理机1C1D启动2个docker容器， 每个组件在单独容器运行|
|物理机数量|2台|

# AntDB容器化设计说明
## 容器主机名设计
**目的**
* 固化容器主机名，方便建立AntDB集群add host 的操作
* 根据按指定规则固化的主机名，可以方便识别AntDB集群节点的组件类型，减少动态参数的传入

**设计规则**

|节点类型|主机名前缀|主机名后缀|
|:-----|:-------|:--------|
|gtm|gtm|不支持后缀|
|coordinator|keyword_cd[0-9]+|无后缀或无限制|
|datanode|keyword_db[0-9]+|无后缀或无限制|

其中主机名前缀keyword设计

|type|可识别的关键字|关键字后缀[0-9]+|
|:-----|:-------|:--------|
|keyword_cd|cd/cn/coordinator|正则表达式，至少1个或N个数字|
|keyword_db|db/dn/datanode|正则表达式，至少1个或N个数字|

**最终主机名**

gtm容器：gtm

coordinator容器：

|coordinator主机名|是否支持|
|:----------------|:------|
|cd1|yes|
|cn1|yes|
|coordinator1|yes|
|cd|no|
|cn|no|
|coordinator|no|
|cd1-china|yes|
|cd1_china|yes|
|china_cd1|no|
|china_cd1_gd|no|

datanode容器：

同coordinator，不赘述。

## 容器内用户设计
|编号	|账号信息	|根目录	|权限|
|:--:|:--------|:-------|:------|
|1	|root/123456	|默认	|默认|
|2	|adb/123456	|/home/adb	|sudo|

## 容器内adb用户目录设计
**目的**
* 按指定规则固化AntDB集群各组件在容器内的数据路径，减少动态参数的传入
* 方便管理

**设计规则**

|目录|目录名是否固定|存储内容|
|:-----|:-------|:--------|
|/home/adb/data/shell	|固定	|dockerfile文件CMD启动脚本&&pgxc_node初始化脚本|
|/home/adb/data/keyword_gtm[0-9]+/keyword_gtm[0-9]+	|不固定	|gtm节点数据|
|/home/adb/data/keyword_cd[0-9]+/keyword_cd[0-9]+	|不固定	|coordinator节点数据|
|/home/adb/data/keyword_db[0-9]+/keyword_db[0-9]+	|不固定	|datanode节点数据|

其中keyword设计

|type	|可识别的关键字	|关键字后缀[0-9]+|
|:-----|:-------|:--------|
|keyword_gtm	|gtm	|正则表达式，至少1个或N个数字|
|keyword_cd	|cd/cn/coordinator	|正则表达式，至少1个或N个数字|
|keyword_db	|db/dn/datanode	|正则表达式，至少1个或N个数字|

注：为了简化容器的主机名和目录名，一般要求主机名和目录名保持一致。如：

容器主机名设计为cd1_china,则容器目录名设计为 /home/adb/data/cd1_china/cd1_china

## 容器映射目录设计
容器目录以 /home/adb/data/cd1_china/cd1_china 为例

宿主机目录以 /home/ips/data/cd1_china/cd1_china 为例

映射关系：-v /home/ips/data/cd1_china: /home/adb/data/cd1_china

目录全路径，出现连续重复的子目录，这种设计其实挺怪异的。主要出于以下几点考虑：

* 为什么不以这种形式映射 -v /home/ips/data/:/home/adb/data

需要考虑同一台宿主机启动多个容器、映射目录又在同一个根目录的情况。如果以根目录映射，则容器间的数据路径可以互相访问。因此，这种映射方式直接放弃。

* 为什么目录全路径，出现连续重复的子目录

这个问题同 为什么不以这种形式映射 

-v /home/ips/data/cd1_china/cd1_china：/home/adb/data/cd1_china/cd1_china

目录映射之后，需要考虑容器和宿主机是否存在同一个系统用户，如不存在、或虽然存在，但是uid/gid不一致，则在initdb时，会出现无权限写的问题。

当然可以在启动容器时，给予系统权限(docker run --privileged=true)来解决无权限写的问题。但是这种系统权限赋予容器后，势必带来安全性风险。因此，这种映射方式直接放弃。

所以只能以这种方式映射-v /home/ips/data/cd1_china: /home/adb/data/cd1_china，并且需要解决 initdb时可能出现无权限写的问题。

解决方式有两种：

1. 宿主机创建和容器一样的用户，包括uid/gid也一致
2. 映射目录赋予777权限，并创建一个同名子目录，initdb即可有权限写磁盘。

方式1，需要修改宿主机的配置，且极可能与现有的uid/gid冲突，直接放弃。最终以方式2处理。

## 容器/etc/hosts文件设计
**目的**

该文件在docker run时，自动生成，无需人为干预。

这里主要强调下文件内 主机名 ，一定要符合步骤1的设计说明，否则init_pgxc_node.sh脚本在解析hosts文件进行初始化pgxc_node表时，极有可能会失败。

**该脚本会解析容器/etc/hosts文件的对应关键字，来确认adb集群中coordinator和datanode的节点名称及对应节点数量。**


**设计规则**


针对coordinator/datanode：

容器主机名=节点名称=数据路径中的连续重复子目录名称=容器名

如：**cd1**=**cd1**=/home/adb/data/**cd1**/**cd1**=**cd1**

针对gtm：

容器主机名[0-9]+=节点名称=数据路径中的连续重复子目录名称=容器名

如：**gtm**1=**gtm1**=/home/adb/data/**gtm1**/**gtm1**=**gtm1**

## 结合docker run 详细说明

```
docker run -d \
-e PARAMS="gtm1&/home/adb/data/gtm1&gtm" 
-v /home/ips/data/gtm1:/home/adb/data/gtm1 \
-p 9435:5432 \
--name gtm1 \
--hostname gtm \
--net=net_adb1 \
--ip 172.30.88.11 \
--add-host gtm:172.30.88.11 \
--add-host cd1:172.30.88.21 \
--add-host cd2:172.30.98.22 \
--add-host db1:172.30.88.31 \
--add-host db2:172.30.98.32 \
adb24
```

--name gtm1 ：容器名称，无限制。便于维护，一般和容器的主机名一致。

gtm容器名称比容器的主机名，一般会多一部分数字编号的后缀。

--hostname gtm ：容器主机名，务必符合步骤1的设计说明。

-v /home/ips/data/gtm1:/home/adb/data/gtm1 ： 根目录(/home/ips/data)+adb数据库节点名称(gtm1).

其中，adb数据库节点名称指，initdb时指定的—nodename参数，如下：

initdb  -D /home/adb/data/cd1/cd1 --nodename cd1 -E UTF8 --locale=C -k

-p 9435:5432 ：端口映射

--net=net_adb1 ：自定义网络名称

--ip 172.30.88.11 ：固定ip

--add-host gtm:172.30.88.11 ： 格式[容器的主机名：固定ip]，自动写入容器hosts文件

-e PARAMS="gtm1&/home/adb/data/gtm1&gtm" ：docker run时携带的参数以符号 & 分割，此处携带了3个参数，由左至右，分别命名为 1,p2,p3.

其中：
* p1 指adb数据库节点名称，即initdb时的—nodename参数，要求和容器主机名一致
* p2 指adb数据库节点数据路径的映射目录，也是数据路径的上一级目录
* p3 指adb数据库节点类型，暂时支持三种类型，固定为：gtm/coordinator/datanode.后续可能会支持adbmgr类型，其他类型不支持。

请务必在docker run时配置正确的上述3个参数。

adb24 ： 镜像名称

# 总结

# 参考
AntDB QQ群号：496464280

[AntDB github链接](https://github.com/ADBSQL)
