
# AntDB容器化应用介绍
***
本文主要探讨AntDB基于docker的虚拟化分布式数据库应用。
通过本文实现下述功能：
* 如何制作AntDB镜像文件
* AntDB镜像支持sshd自启动功能
* 自定义容器网络
* 容器间路由互通的实现
* AntDB基于docker的虚拟化分布式数据库应用

***

# 环境介绍
|操作系统|centos7.4|
|:-----|:-------|
|docker版本|1.13|
|AntDB版本|4.0|
|AntDB架构|2C2D， 每物理机1C1D启动2个docker容器， 每个组件在单独容器运行|
|物理机数量|2台|
|gtm容器ip|172.30.88.11    容器端口映射-> 9435:5432|
|cd1容器ip|172.30.88.21    容器端口映射-> 9432:5432|
|cd2容器ip|172.30.88.22    容器端口映射-> 9432:5432|
|db1容器ip|172.30.88.31    容器端口映射-> 9433:5432|
|db2容器ip|172.30.88.32    容器端口映射-> 9433:5432|


# 制作AntDB镜像文件

联系AntDB团队获取

# 自定义容器网络
`docker network create --subnet=172.30.88.0/24 net_adb1`

# 容器间路由互通
添加路由规则

`route add -net 172.30.98.0 netmask 255.255.255.0 gw 10.21.20.176`

# AntDB基于docker的虚拟化分布式数据库应用
## 具体步骤介绍

1. 在宿主机新建数据目录，即容器映射目录，用于数据持久化

**物理机1：**

mkdir -p /home/ips/data/{cd1,db1,gtm1} 

chmod -R 777 /home/ips/data 

**物理机2：**

mkdir -p /home/ips/data/{cd2,db2} 

chmod -R 777 /home/ips/data

2. 启动容器（物理机1：gtm1、cd1、db1 &&  物理机2：cd2、db2）

**物理机1**

自定义网络

`docker network create --subnet=172.30.88.0/24 net_adb1`

添加路由规则

`route add -net 172.30.98.0 netmask 255.255.255.0 gw 10.21.20.176`

docker run初始化节点

`docker run -d -e PARAMS="gtm1&/home/adb/data/gtm1&gtm" -v /home/ips/data/gtm1:/home/adb/data/gtm1 -p 9435:5432 --name gtm1 --hostname gtm --net=net_adb1 --ip 172.30.88.11 --add-host gtm:172.30.88.11 --add-host cd1:172.30.88.21 --add-host cd2:172.30.98.22 --add-host db1:172.30.88.31 --add-host db2:172.30.98.32 adb24`

`docker run -d -e PARAMS="cd1&/home/adb/data/cd1&coordinator" -v /home/ips/data/cd1:/home/adb/data/cd1 -p 9432:5432 --name cd1 --hostname cd1 --net=net_adb1 --ip 172.30.88.21 --add-host gtm:172.30.88.11 --add-host cd1:172.30.88.21 --add-host cd2:172.30.98.22 --add-host db1:172.30.88.31 --add-host db2:172.30.98.32  adb24`

`docker run -d -e PARAMS="db1&/home/adb/data/db1&datanode" -v /home/ips/data/db1:/home/adb/data/db1 -p 9433:5432 --name db1 --hostname db1 --net=net_adb1 --ip 172.30.88.31 --add-host gtm:172.30.88.11 --add-host cd1:172.30.88.21 --add-host cd2:172.30.98.22 --add-host db1:172.30.88.31 --add-host db2:172.30.98.32  adb24`

**注：**

gtm容器主机名固定为 gtm

coordinator容器主机名支持 以 cd/cn/coordinator[0-9]+ 为前缀，后缀不限制.如 cd1,cd1_china,cn1_china,不支持china_cd1,china_cd1_gd,cd

datanode容器主机名支持 以 db/dn/datanode[0-9]+ 为前缀，后缀不限制

**物理机2**

同物理机1的操作，不赘述

3. 初始化pgxc_node

在任一容器执行下述命令，即可完成全部cd节点的pgxc_node初始化

`docker exec -it cd1 /home/adb/data/shell/init_pgxc_node.sh`

4. 启停节点(启停数据库)

**先停：**

物理机2：docker stop db2 cd2

物理机1：docker stop db1 cd1 gtm1

**再启：**

物理机1：docker start gtm1 cd1 db2

物理机2：docker start cd2 db2

6. ssh登录docker容器

ssh root@172.30.88.11

ssh adb@172.30.88.11

账号初始密码：

root/123456

adb/123456

# 总结
目前AntDB初步具备上云能力，且数据能持久存储。 但在HA高可用、主从架构方面，还不够完善，仍需继续探索。
# 参考
AntDB QQ群号：496464280

[AntDB github链接](https://github.com/ADBSQL)
