
# Oracle连接访问AntDB

#### 数据库版本

database | ip  | 操作系统
---|---|---|---
oracle 11g |  10.21.20.175| centos7
antdb50| 10.21.20.175|centos7
## 操作步骤
### 1、安装postgresql odbc驱动
oracle服务器安装驱动

`yum install postgresql-odbc`

### 2、配置/etc/odbc.ini 文件
```
[AntDB50]
Description = ora2adb
Driver = PostgreSQL
Database = postgres
Servername = 10.21.20.175
UserName = zhoumz
Password = zhoumz
Port = 51432
```
### 3、配置透明网关
在$ORACLE_HOME/hs/admin/下面创建initAntDB50.ora文件,命名规则initDNS_NAME.ora

```
cat initAntDB50.ora 
HS_FDS_CONNECT_INFO = AntDB50
HS_FDS_TRACE_LEVEL = 4
HS_FDS_SHAREABLE_NAME = /usr/lib64/psqlodbc.so
HS_LANGUAGE=AMERICAN_AMERICA.WE8ISO8859P1
#
# ODBC specific environment variables
#
set ODBCINI=/etc/odbc.ini
```
### 4、配置listener.ora文件
```
SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC=
         (SID_NAME=AntDB50)
         (ORACLE_HOME=/ssd/zhoumz/oracle/11g)
         (ENV="LD_LIBRARY_PATH=/usr/lib64:/ssd/zhoumz/oracle/11g/lib:/ssd/zhoumz/oracle/11g/odbc/lib")
         (PROGRAM=dg4odbc)
    )
  )
  重新加载监听
```

### 5、配置tnsnames.ora文件
```
AntDB50  =
  (DESCRIPTION=
    (ADDRESS=(PROTOCOL=tcp)(HOST=10.21.20.175)(PORT=1522))
    (CONNECT_DATA=(SID=AntDB50))
    (HS=OK)
  )

```

### 6、创建dblink
```
create database link antdb connect to "zhoumz" identified by "zhoumz" using 'AntDB50';
```
测试dblink,表名需要加双引号
```
SQL>  select count(*) from  "t1"@antdb;

  COUNT(*)
----------
	 1

```
### 7、遇到的问题和分析方法
```
SQL> select count(*) from "t1"@antdb;
select count(*) from "t1"@antdb
ERROR at line 1:
ORA-28500: connection from ORACLE to a non-Oracle system returned this message:
ORA-02063: preceding line from ANTDB
```
分析方法
在配置文件initAntDB50.ora 里设置trace 级别 能打印日志

```HS_FDS_TRACE_LEVEL = 4```

日志路径在$oracle_home/hs/log，根据日志报错分析原因。

```
Entered hgolofns at 2020/02/06-15:33:28
 libname=/usr/lib64/psqlodbc.so, funcname=SQLGetDescRecW
 peflerr=6521, libname=/usr/lib64/psqlodbc.so, funcname=SQLGetDescRecW
 hoaerr:28500
Exiting hgolofns at 2020/02/06-15:33:28
Failed to load ODBC library symbol: /usr/lib64/psqlodbc.so(SQLGetDescRecW)
Exiting hgolofn, rc=28500 at 2020/02/06-15:33:28
Exiting hgoinit, rc=28500 with error ptr FILE:hgoinit.c LINE:337 FUNCTION:hgoinit() ID:Loading ODBC aray of function ptrs
Entered hgoexit
HS Gateway:  NULL connection context at exit
Exiting hgoexit, rc=0 with error ptr FILE:hgoexit.c LINE:108 FUNCTION:hgoexit() ID:Connection context
```
能看出来加载odbc驱动时有问题，结合日志和查询资料，最终发现是因为配置文件里字符集设置错误，配置文件字符集改成AMERICAN_AMERICA.WE8ISO8859P1，此问题就解决了。

