

# PostgreSQL 坏块扫描

## 何为坏块

引起数据读取异常的数据块，包括无法读取数据的情况和读取不到正确数据的情况

## 产生原因

导致数据文件出现坏块的原因有物理存储方面的原因，操作系统异常或者其他软件误操作等原因。

物理层面引起的坏块需要更换硬件来解决，生产环境存储多为raid冗余模式，服务器出现告警后可及时更换硬件解决，这里不做深入讨论。

## 坏块扫描工具pg_check

pg_check 可以检查表数据和索引文件，扫描出数据坏块。

可检查项：

1. 表数据文件page header检查
2.  索引文件检查(仅限btree索引) 
3. 表单行记录完成性检查。
4.  无效的varlena大小 (变长内部类型，不能大于1G或者是负数)

**注意：**检查表数据时，默认会检查表上的索引，并且校验索引记录和数据记录，需要在表上加SHARE ROW EXCLUSIVE 锁，根据实际业务的情况，灵活选择扫描项。

参考以下语法。

```
select pg_check_table('tabname');  扫描表上索引并且加排它锁
select pg_check_table('tabname',true,false);扫描表上索引不加排它锁
select pg_check_table('tabname',false,false); 不扫描表上索引不加排它锁
```



## 表数据坏块分析



### 无效页坏块

```
ERROR: invalid page in block %u of relation %s
```

创建测试表和测试数据

```
create table t1(id int,name varchar);
insert into t1 select id,id||'name' from generate_series(1,200) t(id);
checkpoint;
```

查看表对应的文件

```
[local]:5432 postgres@test=# select pg_relation_filepath('t1');
 pg_relation_filepath 
----------------------
base/16605/41216
(1 row)
```

#### 模拟坏块

通过修改表对应的数据文件，破坏数据库正常的存储规则，模拟坏块。

关闭数据库（防止内存中的数据倒刷回数据文件）

查看数据文件的二进制信息

```
[postgres@node1 data]$  hexdump  base/16605/41216|head -n 2
0000000 0000 0000 8110 ad0e 0000 0000 02fc 0318
0000010 2000 2004 0000 0000 9fd8 0044 9fb0 0044
```

用dd命令修改表数据文件，将pd_lower修改成大于pd_upper的值,第一行末02fc修改为03fc(大于0318)

```
printf "\x03" |dd of=base/16605/41216 bs=1 count=1 seek=13 conv=notrunc
```

```
[postgres@node1 data]$  hexdump  base/16605/41216|head -n 2
0000000 0000 0000 8110 ad0e 0000 0000 03fc 0318
0000010 2000 2004 0000 0000 9fd8 0044 9fb0 0044
```

启动数据库查询表数据，报错信息如下。

```
[postgres@node1 data]$ psql -c "select count(*) from t1"
ERROR:  invalid page in block 0 of relation base/16605/41216
```

pg_check 检查

```
[postgres@node1 data]$ psql -c "select pg_check_table('t1',false,false);"
ERROR:  invalid page in block 0 of relation base/16605/41216
```

#### 找回数据

在slave节点查看数据正常

```
[postgres@node2 ~]$  psql -c "select count(*) from t1"
 count 
-------
   200
(1 row)
```

此种情况主节点数据异常，备节点数据正常，可将备节点数据导出，在主节点上重新建表。



### 行属性错误坏块

创建测试表和数据

```
test=# create table t3(id int,name varchar);
test=# insert into t3 values(1,'test')
test=# checkpoint;
```

查找表对应数据文件

```
test=# select pg_relation_filepath('t3');
 pg_relation_filepath 
----------------------
 base/16605/41365
```

#### 模拟坏块

查看二进制文件

```
[postgres@node1 data]$ hexdump -C base/16605/41365
00000000  00 00 00 00 60 0d 36 ad  00 00 00 00 1c 00 d8 1f  |....`.6.........|
00000010  00 20 04 20 00 00 00 00  d8 9f 42 00 00 00 00 00  |. . ......B.....|
00000020  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
*
00001fd0  00 00 00 00 00 00 00 00  78 09 04 00 00 00 00 00  |........x.......|
00001fe0  00 00 00 00 00 00 00 00  01 00 02 00 02 08 18 00  |................|
00001ff0  01 00 00 00 0b 74 65 73  74 00 00 00 00 00 00 00  |.....test.......|
```

使用 pageinspect 插件查看行数据栏位属性

```
test=# select * from heap_page_items(get_raw_page('t3',0));
 lp | lp_off | lp_flags | lp_len | t_xmin | t_xmax | t_field3 | t_ctid | t_infomask2 | t_infomask | t_hoff | t_bits | t_oid |        t_data        
----+--------+----------+--------+--------+--------+----------+--------+-------------+------------+--------+--------+-------+----------------------
  1 |   8152 |        1 |     33 | 264568 |      0 |        0 | (0,1)  |           2 |       2050 |     24 |        |       | \x010000000b74657374
(1 row)
```

可以看到t_infomask2为2，行里有两列数据。我们来修改这个数值

##### 改大列属性值

从刚才查看的行信息中查看第一行数据偏移量为lp_off=8152，t_infomask2在HeapTupleHeaderData（数据行头）里是19，20字节

```
[postgres@node1 data]$ hexdump -C base/16605/41365 -s 8170 -n 2
00001fea  02 00                                             |..|
00001fec
```

```
用dd命令修改对应数据
printf "\x3" |dd of=base/16605/41365 bs=1 count=1 seek=8170 conv=notrunc
```

```
[postgres@node1 data]$ hexdump -C base/16605/41365 -s 8170 -n 2
00001fea  03 00                                             |..|
00001fec
```

启动数据库查询表数据

```
test=# select * from t3;
 id | name 
----+------
  1 | test
(1 row)
```

查询出来数据正常

使用pg_check_table 查看

```
test=# select pg_check_table('t3');
DEBUG:  [0] header [lower=28, upper=8152, special=8192 free=8124]
DEBUG:  [0] max number of tuples = 1
DEBUG:  [0:1] tuple is LP_NORMAL
DEBUG:  [0:1] checking attributes for the tuple
WARNING:  [0:1] tuple has too many attributes. 3 found, 2 expected
WARNING:  [0] is probably corrupted, there were 1 errors reported
 pg_check_table 
----------------
              1
(1 row)
```

发现错误，表栏位数和数据中的值不一致，这种情况下问题隐藏比较深，普通查询不一定能暴露出问题，用工具可以扫描出错误。

##### 改小列属性值

下面我们来改小栏位属性值，看看出现什么问题

```
[postgres@node1 data]$ printf "\x1" |dd of=base/16605/41365 bs=1 count=1 seek=8170 conv=notrunc
1+0 records in
1+0 records out
1 byte (1 B) copied, 3.9351e-05 s, 25.4 kB/s
[postgres@node1 data]$ hexdump -C base/16605/41365 -s 8170 -n 2
00001fea  01 00                                             |..|
00001fec
```

查询表数据，发现name列没有值

```
test=# select * from t3;
 id | name 
----+------
  1 | 
```

查看备机数据，备机数据正常。

```
[postgres@node2 ~]$ psql -c "select * from t3;"
 id | name 
----+------
  1 | test
```

使用pg_check_table 检查

```
test=#  select pg_check_table('t3');
WARNING:  [0:1] tuple has too few attributes. 1 found, 2 expected
WARNING:  [0] is probably corrupted, there were 1 errors reported
 pg_check_table 
----------------
              1
(1 row)
```

此种情况下，会出现真实数据为空的问题，不仔细思考，可能误以为此处本来就没有值，问题隐藏比较深，但是工具可以扫描出问题。



## 索引坏块分析

索引数据有坏块时

1. 通过索引查询数据会报错
2. 索引记录的数据和表数据不对应

### 索引页损坏

创建测试表和数据

```
create table t4(id int,name varchar,constraint t4_pkey primary key  (id));
insert into t4 select id,id||'name' from generate_series(1,10) t(id);
```

查找索引对应的数据文件

```
test=# select pg_relation_filepath('t4_pkey');
 pg_relation_filepath 
----------------------
 base/16605/41416
```

查看索引元数据信息

```
test=# select * from bt_metap('t4_pkey');
 magic  | version | root | level | fastroot | fastlevel | oldest_xact | last_cleanup_num_tuples 
--------+---------+------+-------+----------+-----------+-------------+-------------------------
 340322 |       3 |    1 |     0 |        1 |         0 |           0 |                      -1

```

查看索引root页信息

```
test=# select * from page_header(get_raw_page('t4_pkey',1));
    lsn     | checksum | flags | lower | upper | special | pagesize | version | prune_xid 
------------+----------+-------+-------+-------+---------+----------+---------+-----------
 0/AD3C1658 |        0 |     0 |    64 |  8016 |    8176 |     8192 |       4 |         0
```

#### 模拟坏块

索引页头结构和数据页头结构相同，参考前面方法，修改索引页中lower和upper数值。

```
[postgres@node1 data]$ hexdump -C base/16605/41416 -s 8192 |head -n 2
00002000  00 00 00 00 58 16 3c ad  00 00 00 00 40 00 50 1f  |....X.<.....@.P.|
00002010  f0 1f 04 20 00 00 00 00  e0 9f 20 00 d0 9f 20 00  |... ...... ... .|

[postgres@node1 data]$ printf "\x20" |dd of=base/16605/41416 bs=1 count=1 seek=8205 conv=notrunc
1+0 records in
1+0 records out
1 byte (1 B) copied, 4.1965e-05 s, 23.8 kB/s
[postgres@node1 data]$ hexdump -C base/16605/41416 -s 8192 |head -n 2
00002000  00 00 00 00 58 16 3c ad  00 00 00 00 40 20 50 1f  |....X.<.....@ P.|
00002010  f0 1f 04 20 00 00 00 00  e0 9f 20 00 d0 9f 20 00  |... ...... ... .|

```

启动数据库，查询t4表数据

```
test=# explain analyse select * from t4;
                                                    QUERY PLAN                                                     
-------------------------------------------------------------------------------------------------------------------
 Seq Scan on t4  (cost=10000000000.00..10000000001.10 rows=10 width=36) (actual time=0.005..0.006 rows=10 loops=1)
 Planning Time: 0.028 ms
 Execution Time: 0.012 ms
(3 rows)
查询正常
下面来看看走索引查询的情况，由于测试数据量小，这里关闭顺序扫描，强制走索引
set enable_seqscan=off;
test=# explain analyse select * from t4 where id=5;
ERROR:  invalid page in block 1 of relation base/16605/41416
走索引查询后，由于索引页异常，导致查询异常。
```

pg_check查询索引页

```
[postgres@node1 ~]$ psql -c "select  pg_check_index('t4_pkey');"
NOTICE:  checking index: t4_pkey
ERROR:  invalid page in block 1 of relation base/16605/41416
```

索引页损坏后，可通过重建索引解决坏块问题

```
test=# reindex index t4_pkey;
REINDEX
test=# explain analyse select * from t4 where id=5;
                                                 QUERY PLAN                                                  
-------------------------------------------------------------------------------------------------------------
 Index Scan using t4_pkey on t4  (cost=0.14..8.15 rows=1 width=36) (actual time=0.010..0.011 rows=1 loops=1)
   Index Cond: (id = 5)
 Planning Time: 0.372 ms
 Execution Time: 0.049 ms
(4 rows)
```



## 检查系统表损坏

使用pg_catcheck 检查系统表是否有损坏

pg_catcheck  安装简单，下载源码后make，make install即可。

源码地址: 
```
https://github.com/EnterpriseDB/pg_catcheck
```

使用方法：

```
[postgres@node1 pg_catcheck-master]$ pg_catcheck --help
pg_catcheck is catalog table validation tool for PostgreSQL.

Usage:
  pg_catcheck [OPTION]... [DBNAME]

Options:
  -c, --column             check only the named columns
  -t, --table              check only columns in the named tables
  -T, --exclude-table      do NOT check the named tables
  -C, --exclude-column     do NOT check the named columns
  --target-version=VERSION assume specified target version
  --enterprisedb           assume EnterpriseDB database
  --postgresql             assume PostgreSQL database
  -h, --host=HOSTNAME      database server host or socket directory
  -p, --port=PORT          database server port number
  -q, --quiet              do not display progress messages
  -U, --username=USERNAME  connect as specified database user
  -v, --verbose            enable verbose internal logging
  -V, --version            output version information, then exit
  -?, --help               show this help, then exit

```
有多个库的话，每个库运行一次pg_catcheck
```
[postgres@node1 pg_catcheck-master]$ pg_catcheck -p 5432  test
progress: done (0 inconsistencies, 0 warnings, 0 errors)

[postgres@node1 pg_catcheck-master]$ pg_catcheck -p 7432  postgres
progress: done (0 inconsistencies, 0 warnings, 0 errors)

从结果中看出没有不一致，没有告警，没有错误
```

pg_catcheck  只能检查系统表是否有损坏，没有修复的功能，可作为故障诊断的辅助工具。



## 总结

1. pg_check 工具可以扫描出表和索引中(仅限btree索引)的坏块
2. pg_check 校验表数据和对应索引时会对表加排它锁。
3. 表数据出现坏块后可通过备节点恢复数据
4. 索引出现坏块后可尝试重建索引解决问题
5. pg_catcheck 可以检查系统表是否损坏
6. 生产环境务必保证备份完整，开启归档，一主多从架构，数据多副本保存

