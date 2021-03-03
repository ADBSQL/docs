# AntDB 连接 MySQL 
### 1、编译mysql_fdw 
-  在mgr主机安装mysql 客户端和开发包，可在mysql网站下载
```
 mysql-community-common-8.0.19-1.el7.x86_64.rpm
 mysql-community-libs-8.0.19-1.el7.x86_64.rpm
 mysql-community-client-8.0.19-1.el7.x86_64.rpm
 mysql-community-devel-8.0.19-1.el7.x86_64.rpm
```
- 准备mysql_fdw ,https://github.com/EnterpriseDB/mysql_fdw
```
确保mysql_config 和pg_config 在$PATH 环境变量里能找到
进入mysql_fdw 文件夹执行
make USE_PGXS=1
make USE_PGXS=1 install
```

### 2、创建mysql_fdw
- 在mgr主机复制/usr/lib/mysql下的lib文件到antdb 安装路径下的lib文件夹
- deploy 到各个主机节点
- 连接集群中cn节点执行

```
create extension mysql_fdw;

CREATE SERVER mysql_server FOREIGN DATA WRAPPER mysql_fdw
OPTIONS (host '10.21.20.176', port '51306');

CREATE USER MAPPING FOR zhoumz SERVER mysql_server
OPTIONS (username 'root', password 'root');

CREATE FOREIGN TABLE warehouse(
     warehouse_id int,
     warehouse_name text,
     warehouse_created timestamp)
SERVER mysql_server
     OPTIONS (dbname 'test', table_name 'warehouse');
     
```
### 3、使用mysql_fdw
```
-- insert new rows in table
INSERT INTO warehouse values (1, 'UPS', now());
INSERT INTO warehouse values (2, 'TV', now());
INSERT INTO warehouse values (3, 'Table', now());

[local]:51432 zhoumz@postgres=# select * from warehouse;
 warehouse_id | warehouse_name |  warehouse_created  
--------------+----------------+---------------------
            1 | UPS            | 2020-02-10 16:31:50
            2 | TV             | 2020-02-10 16:33:00
            3 | Table          | 2020-02-10 16:33:00
(3 rows)

```

### 4、遇到的问题
#####  1、访问mysql 报错
```
[local]:51432 zhoumz@postgres=# select * from t1;
ERROR:  failed to connect to MySQL: Host 'node1' is not allowed to connect to this MySQL server
```
mysql对连接请求有准入机制，检查一下user mapping 对应的用户是否有权限访问mysql服务器的权限

##### 2、insert 操作报错
```
[local]:51432 zhoumz@postgres=# insert into t1 values(123,'ab');
ERROR:  first column of remote table must be unique for INSERT/UPDATE/DELETE operation
```
根据EnterpriseDB介绍，这是mysql_fdw使用限制，dml操作的首个栏位需要是带有唯一性约束的列。
https://github.com/EnterpriseDB/mysql_fdw/issues/96

##### 3、delete/update 产生core 
同issue http://10.20.16.216:9090/ADB/adb_sql/issues/150






