## AntDB版本替换文档

- 文档名称：《AntDB版本替换文档》
- 对象：DBA/运维/系统管理员

---

### 准备工作

#### 版本替换的前提条件

版本替换需要对antdb集群进行起停操作，所以需要业务侧配合业务的起停。

#### 获取新版本rpm包

联系AntDB交付人员获取如下信息：

- 新版本的rpm安装包

- 安装包文件的md5值，上传到`adbmgr`所在主机后需要核对md5是否一致

- 是否需要初始化`adbmgr`

- 是否需要初始化数据库

- 版本更新内容

- 其他需要单独执行的语句


rpm包的文件命名如下：

```
antdb-5.0.7059231b-centos7.4.rpm
```

####  上传rpm包

上传rpm包到`adbmgr`所在主机的 ~/soft 目录下。

> 根据现场的环境，修改目录。

####   查看集群状态

`adbmgr` 所在主机，antdb用户：

登录adbmgr， 命令行执行 ：`psql -p 6432 -d postgres -U antdb`  进入adbmgr操作界面。

`monitor all; ` -- 查看集群各个节点的状态均为running

`monitor agent all;` --  查看各个主机上的agent状态均为running

确认应用没有session连接到AntDB ：

在主机命令行执行： `psql ` 进入psql界面，执行：

`select * from pg_stat_activity where state<>'idle'`

查询结果为空即可。

> 如果确定即使有应用的连接也不影响，那可以忽略session检查的步骤
>

###开始替换

#### 停止集群

`adbmgr` 所在主机，antdb用户：

`psql -p 6432`  -- 登录adbmgr

`set doctor (enable=0);` -- 停止doctor

> 如果启用了doctor，则在这步先停止。

`stop all mode fast; `  --停止所有节点

`stop agent all; `  --停止所有agent

#### 备份adbmgr数据(可选)

如果antdb交付人员告知此次版本替换需要初始化adbmgr，则执行此步骤。如果不需要初始化adbmgr，则跳过此步骤。

`adbmgr` 所在主机，antdb用户：

备份adbmgr中的配置数据：

```
mgr_dump -p 6432 -d postgres --mgr_table -f ~/soft/mgr_table_1204.sql
```

备份adbmgr中的monitor数据：

```
mgr_dump "port=6432 dbname=postgres options='-c command_mode=sql'" -t 'monitor_*' -a -f ~/soft/monitor_data_1204.sql
```

备份adbmgr数据目录： 

```
cp -r /data/adb/mgr /data/adb/mgr_0818    -- 备份整目录
du -sh /data/adb/mgr*     -- 查看备份目录和原始目录大小一致
```

> 注意替换为现场的实际目录
>

#### 停止adbmgr

在`adbmgr` 所在主机上命令行操作：

`mgr_ctl stop -D /data/adb/mgr -m fast `

> 如果有 adbmgr slave存在，同样也要停止。

#### 备份adbhome

在`adbmgr` 所在主机上命令行操作：

```
echo $ADB_HOME
cp -r /opt/app/antdb /opt/app/antdb_1204
du -sh /opt/app/antdb*     -- 查看备份目录和原始目录大小一致
```

####卸载旧版本

在`adbmgr` 所在主机上命令行操作：

查看目前安装的antdb rpm包：

`rpm -qa |grep antdb`

查询结果类似如下：

```
antdb-5.0.7bcad689-10.el6.x86_64.rpm 
```

切换到root用户，进行旧版本的卸载：

```
rpm -e antdb-5.0.7bcad689-10.el6.x86_64.rpm 
rpm -e antdb-debuginfo-5.0.7bcad689-10.el6.x86_64.rpm
```

如果安装了debuginfo的包，在剩余的几台主机上使用root用户分别执行：

`rpm -e antdb-debuginfo-5.0.7bcad689-10.el6.x86_64.rpm `

在所有主机上再次检查：

`rpm -qa |grep antdb`

#### 安装新版本

在`adbmgr` 所在主机上切换到rpm包存放目录：

cd ~/soft

使用root用户执行：

```
rpm -ivh antdb-5.0.4d6d85d9-10.el6.x86_64.rpm  
```

### 启动集群

#### 初始化adbmgr(可选)

如果antdb交付人员告知此次版本替换需要初始化adbmgr，则执行此步骤。如果不需要初始化adbmgr，则跳过此步骤。

`adbmgr` 所在主机，antdb用户：

初始化adbmgr：

(**执行之前一定要检查下之前的备份操作是否执行，备份数据是否存在**)

```
initmgr -D path /data/adb/mgr
```

恢复adbmgr的参数文件和hba文件：

```
cp /data/adb/mgr_0818/postgresql.conf  /data/adb/mgr/postgresql.conf
cp /data/adb/mgr_0818/pg_hba.conf  /data/adb/mgr/pg_hba.conf
```

> 注意：替换为实际的数据目录
>

#### 启动adbmgr

在`adbmgr` 所在主机上执行：

`mgr_ctl start -D /data/adb/mgr`

####恢复adbmgr的数据(可选)

如果antdb交付人员告知此次版本替换需要初始化adbmgr，则执行此步骤。如果不需要初始化adbmgr，则跳过此步骤。

`adbmgr` 所在主机，antdb用户：

恢复adbmgr的配置数据：

```
psql -p 6432 -d postgres -f ~/soft/mgr_table_1204.sql
```

恢复adbmgr的monitor数据：

```
psql "port=6432 dbname=postgres options='-c command_mode=sql'" -f ~/soft/monitor_data_1204.sql
```

无报错即可。

#### 发布二进制程序

在`adbmgr` 所在主机上 `psql -p 6432 `进入adbmgr操作界面：

`list host;  `--检查主机

`list node; ` -- 检查节点

`monitor agent all; `--检查agent均为 `not running`状态

开始部署二进制文件：

`deploy all; `

####  检查各个主机上的antdb版本

在各个主机上使用antdb用户执行：

`postgres -V `

所有主机返回结果均一样即可。

#### 启动集群

在`adbmgr` 所在主机上执行 `psql -p 6432 `进入adbmgr操作界面：

`start agent all; `--启动所有主机上的agent进程

`start all; `  -- 启动所有节点

`monitor all;` -- 所有节点的状态应该均为 running

`monitor hal;` -- 检查节点流复制情况

如果集群本身需要启动doctor，则在这步启动doctor：
`set doctor (enable=1);`

####重新拉adbmgr slave(可选)

如果antdb交付人员告知此次版本替换需要初始化adbmgr，则执行此步骤。如果不需要初始化adbmgr，则跳过此步骤。

`adbmgr slave`所在主机，antdb用户：

```
mv /data/adb/mgr /adbdata/adb/mgr_bak
pg_basebackup -h adb05 -p 6433 -U adb -D /data/adb/mgr -Xs -Fp -R
chmod 700 /data/adb/mgr
```

> 注意：替换为实际的数据目录
>

####启动adbmgr slave(可选)

存在adbmgr slave的情况下：

`adbmgr slave`所在主机，antdb用户：

```
mgr_ctl start -D /data/adb/mgr 
```

###尾声

有任何问题，请联系AntDB交付人员。

 

 

 

 

 

 

 