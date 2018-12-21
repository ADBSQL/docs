
# AntDB wal_compression日志压缩性能对比测试@20181220
***

AntDB在写频繁的场景中，会产生大量的WAL日志，如果有索引的情况下，WAL日志量会远超实际更新的数据量。 

造成这种情况的主要原因有2点： 
* 在checkpoint之后第一次修改页面，需要在WAL中输出整个page，即全页写FPI(full page writes)，默认8KB。
* 更新记录时如果新记录位置(ctid)发生变更，索引记录也要相应变更。更严重的是索引记录的变更又有可能导致索引页的全页写，进一步加剧了WAL写放大。而pg的更新过程，是将记录标记为无效后，插入一条新记录。当fillfactor=100%的情况下，就会产生FPI。

WAL的优化:
* 增加HOT_UPDATE比例--fillfactor

    普通的UPDATE经常需要更新2个数据块，并且可能还要更新索引page，这些又都有可能产生FPI。
    而HOT_UPDATE只修改1个数据块，需要写的WAL量也大大减少。 
* WAL日志压缩--wal_compression

    打开wal_compression参数，设为on可以对FPI进行压缩，削减WAL的大小。

***

**本文主要探讨AntDB在批量INSERT/UPDATE场景下，上述两个参数在WAL日志压缩和SQL执行性能之间的测试情况。**

## 环境介绍

|操作系统|centos7.4|
|:---|:------|
|内存|128GB|
|磁盘|SSD|
|AntDB版本|4.0|
|AntDB架构|2C2D|


***

## 批量INSERT对比测试

### 测试方法

通过copy方式向pgbench模型的orders表导入2GB数据量，AntDB每个datanode实例处理1GB的数据量。

`copy orders from '/home/adb40sy/orders.csv' with csv;`

### 测试场景

|no|wal_compression|fillfactor|
|:---:|:------|:----|
|1|off|100%|
|2|on|100%|
|3|on|90%|
|4|on|80%|

### 测试结果

![](https://github.com/greatebee/AntDB/blob/master/pic/wal_compression_1.jpg)

### 结果分析

1. INSERT 场景，WAL Size   几乎不受 wal_compression、fillfactor 影响
2. INSERT 场景，INSERT效率 几乎不受 wal_compression、fillfactor 影响


***

## 批量UPDATE 对比测试-更新全页

###  测试方法

全量更新pgbench模型的orders表

`update orders set o_orderdate = now();`

### 测试场景

同上

### 测试结果

![](https://github.com/greatebee/AntDB/blob/master/pic/wal_compression_2.png)

### 结果分析

1. UPDATE 场景，WAL size   几乎不受fillfactor 影响
2. UPDATE 场景，WAL size   受wal_compression一定影响，WAL 日志的FPI size 压缩效果明显
3. UPDATE 场景，UPDATE效率 受wal_compression一定影响，大约降低 5% - 15%
4. 该场景几乎等同于批量INSERT的场景，因此WAL日志数据量比纯INSERT的日志量还要庞大，是其2倍。
增长量主要由于大量全页更新产生的FPI增长。wal_compression的作用主要就是压缩FPI部分的size



***

## 批量UPDATE 对比测试-更新单列
###  测试方法

全量更新pgbench模型进行压测

`pgbench -c 100 -T 1200 -j 100 -d postgres -p 7432 -r `

### 测试场景

同上

### 测试结果

![](https://github.com/greatebee/AntDB/blob/master/pic/wal_compression_3.png)

### 结果分析

1. UPDATE 场景，WAL size    受wal_compression、fillfactor 较大影响，压缩效果明显
2. UPDATE 场景，UPDATE效率  受wal_compression一定影响，大约降低 10% - 17%
3. 该场景主要也是压缩FPI的size，效果显著

## 总结




## 参考
AntDB QQ群号：496464280

[AntDB github链接](https://github.com/ADBSQL)

[wal_compression压缩性能对比测试20181220.xlsx](https://github.com/greatebee/AntDB/blob/master/attach/wal_compression%E5%8E%8B%E7%BC%A9%E6%80%A7%E8%83%BD%E5%AF%B9%E6%AF%94%E6%B5%8B%E8%AF%9520181220.xlsx)
