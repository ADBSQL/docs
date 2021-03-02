
# 全局日志相关说明

全局日志主要设计用于查询整个集群中所有 CN，DN master 节点的日志信息，考虑到用途的不同，分为两个不同的版本：

1. **数据库函数查询接口**： 可以借用 SQL 的便利性进行日志内容的汇总，过滤和排序，效率较慢
2. **pg_logview.py 脚本工具**： 直接在主机命令行使用，效率较高（依赖部分数据库函数）

在数据库层面依赖项：

1. plpythonu 语言 
2. pgxc_node 表（单机版原则上也可以使用）


## 相关脚本

```
Global_Logfile.sql
pg_logviewer.py
```

其中： 
1. `Global_Logfile.sql` 脚本实现了数据库查询接口
2. `pg_logviewer.py` 脚本实现了主机层面的查询接口


## 注意事项

1. 需要使用超级用户登录，创建 plpythonu 语言
2. 关于节点间访问的密码（默认使用当前登录的用户，以及同名密码）
    * 配置节点间的免密登录（即 pg_hba.conf 中配置为 trust 认证）
    * 在脚本运行主机安装了 psycopg2 模块，可以输入登录密码
3. 目前全局日志查询了 pgxc_node 中记录的所有 Coordinator 和 Datanode 节点


## 使用方式（主机查询接口）

1. 使用超级用户登录 postgres 库（或其他库），运行创建脚本：

```shell
psql -U antdb -h localhost -d postgres -f Global_Logfile.sql
```

2. 查看 pg_logviewer.py 工具的帮助信息

```shell
hongyedba@RihuadeMacBook-Pro AMCA_Server % python3 pg_logviwer.py -h

Introduction: 
    pg_viewer is python tool to lookup pg logs in cluster environment.
    trust maybe needed for the user to login all the cluster nodes.
    If psycopg2 module have been installed, you can lookup remote logs, and use continue mode.

Options: 
    -H, --host       : CN/GC host, default from env PGHOST or 127.0.0.1
    -P, --port       : CN/GC port, default from env PGPORT or 5432
    -D, --database   : CN/GC database, will used to create python language and functions, default from env PGDATABASE or postgres
    -U, --user       : CN/GC user, default from env PGUSER or hongyedba
    -W, --password   : CN/GC password used with psycopg2 command mode
    -b, --begin      : Log begin time, default now() - 10 mins
    -e, --end        : Log end time, default now()
    -f, --re_filter  : Log filter with regular expression, default ''
    -n, --node_filter: Only show log data of given nodes (node_name combined with comma), default '*'
    -s, --batch_size : Batch size in screen output and process reading, default 32
    -a, --all        : Show all log data without suspend
    -c, --continue   : Continue to read current log data without suspend [module psycopg2 needed]
    -h, --help       : Show current help message
    -v, --version    : Show current server version

Usage: 
    1. Running on current database node, with all env prepared
       a. Continue mode [need psycopg2 module]
          python pg_logviwer.py -c
       b. Lookup logs within a time range
          python pg_logviwer.py -b '2020-20-20 02:02:02' -e '2020-20-20 12:12:12'
       c. Show all logs in last 10 minutes without suspend
          python pg_logviwer.py -a
    2. Running on remote [need psycopg2 module]
       python pg_logviwer.py -H <host> -P <port> -D <db_name> -U <user> -W <password> -b <begin_time> -e <end_time>
```

3. 具体使用方式参考命令帮助信息，有以下注意事项
    * 默认查询最近 10 分钟的日志内容
    * 脚本输出的内容默认已经按照时间排序，无法修改排序规则，每行日志前会输出当前日志的节点名称
    * 默认脚本每个批次之后会暂停，等待用户输入回车继续，或者输入 q 退出，避免日志太多刷屏
    * 可以使用 -a 选项关闭中间的暂停操作，即一口气显示所有的符合条件的日志内容
    * 在安装了 psycopg2 模块的前提下，可以使用远程查询以及持续查询模式，持续模式类似于操作系统 tail 命令


## 使用方式（数据库查询接口）

1. 使用超级用户登录 postgres 库（或其他库），运行创建脚本：

```shell
psql -U antdb -h localhost -d postgres -f Global_Logfile.sql
```

2. 查看全局日志相关函数和类型

```sql
postgres=# \df gvf*
                                                                                                                                          List of functions
 Schema |        Name        |     Result data type     |                                                                                                         Argument data types                                                                                                         | Type 
--------+--------------------+--------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+------
 public | gvf_create_index   | void                     | pi_logfile_name text, pi_debug_level integer DEFAULT 0                                                                                                                                                                              | func
 public | gvf_file_range     | SETOF gvf_log_range_type | pi_begin_time text DEFAULT to_char((clock_timestamp() - '00:10:00'::interval), 'yyyy-mm-dd HH24:mi:ss'::text), pi_end_time text DEFAULT to_char(clock_timestamp(), 'yyyy-mm-dd HH24:mi:ss'::text), pi_debug_level integer DEFAULT 0 | func
 public | gvf_global_logfile | SETOF gvf_log_item_type  | pi_begin_time text DEFAULT to_char((clock_timestamp() - '00:10:00'::interval), 'yyyy-mm-dd HH24:mi:ss'::text), pi_end_time text DEFAULT to_char(clock_timestamp(), 'yyyy-mm-dd HH24:mi:ss'::text), pi_debug_level integer DEFAULT 0 | func
 public | gvf_local_logfile  | SETOF gvf_log_item_type  | pi_begin_time text DEFAULT to_char((clock_timestamp() - '00:10:00'::interval), 'yyyy-mm-dd HH24:mi:ss'::text), pi_end_time text DEFAULT to_char(clock_timestamp(), 'yyyy-mm-dd HH24:mi:ss'::text), pi_debug_level integer DEFAULT 0 | func
 public | gvf_read_logfile   | SETOF text               | pi_file text, po_read_position bigint DEFAULT 0, pi_end_position bigint DEFAULT '-1'::integer, pi_line_limit integer DEFAULT 100, pi_re_filter text DEFAULT ''::text                                                                | func
(5 rows)

postgres=# \d gvf*
           Composite type "public.gvf_log_item_type"
         Column         | Type | Collation | Nullable | Default 
------------------------+------+-----------+----------+---------
 node_name              | text |           |          | 
 log_time               | text |           |          | 
 user_name              | text |           |          | 
 database_name          | text |           |          | 
 process_id             | text |           |          | 
 connection_from        | text |           |          | 
 session_id             | text |           |          | 
 session_line_num       | text |           |          | 
 command_tag            | text |           |          | 
 session_start_time     | text |           |          | 
 virtual_transaction_id | text |           |          | 
 transaction_id         | text |           |          | 
 error_severity         | text |           |          | 
 sql_state_code         | text |           |          | 
 message                | text |           |          | 
 detail                 | text |           |          | 
 hint                   | text |           |          | 
 internal_query         | text |           |          | 
 internal_query_pos     | text |           |          | 
 context                | text |           |          | 
 query                  | text |           |          | 
 query_pos              | text |           |          | 
 location               | text |           |          | 
 application_name       | text |           |          | 

        Composite type "public.gvf_log_range_type"
     Column     |  Type  | Collation | Nullable | Default 
----------------+--------+-----------+----------+---------
 file_name      | text   |           |          | 
 begin_position | bigint |           |          | 
 end_position   | bigint |           |          | 
```

3. 使用全局日志查询函数

```sql
select count(*) from gvf_global_logfile;
select * from gvf_global_logfile;
select * from gvf_local_logfile;
```
