

### 测试环境

`10.21.20.175`

### 安装过程

#### 安装ZFS

##### 在线安装ZFS

```shell
yum install http://download.zfsonlinux.org/epel/zfs-release.el7_4.noarch.rpm
yum install zfs
which zfs
modprobe zfs
lsmod |grep zfs
```

##### 离线安装ZFS

在在线环境通过yum下载ZFS以及相关依赖：

```
mkdir -p /root/zfs-soft
yum install --downloadonly --downloaddir=/root/zfs-soft zfs
yum install --downloadonly --downloaddir=/root/zfs-soft createrepo
```

将文件夹打包上传到离线环境后解压。

安装本地yum repo

```
rpm -ivh createrepo-0.9.9-28.el7.noarch.rpm
createrepo  /root/zfs-soft
cat > /etc/yum.repos.d/zfs_local.repo << EOF
[zfs]
name=zfs_local
baseurl=file:///root/zfs-soft
enabled=1 
EOF
```

本地安装ZFS：

```
yum install zfs

Dependencies Resolved

=================================================================================================================================================================
 Package                                   Arch                       Version                               Repository                                      Size
=================================================================================================================================================================
Installing:
 zfs                                       x86_64                     0.7.12-1.el7_4                        /zfs-0.7.12-1.el7_4.x86_64                     1.1 M
Installing for dependencies:
 dkms                                      noarch                     2.7.1-1.el7                           zfs                                             75 k
 elfutils-libelf-devel                     x86_64                     0.172-2.el7                           zfs                                             39 k
 libnvpair1                                x86_64                     0.7.12-1.el7_4                        zfs                                             31 k
 libuutil1                                 x86_64                     0.7.12-1.el7_4                        zfs                                             36 k
 libzfs2                                   x86_64                     0.7.12-1.el7_4                        zfs                                            131 k
 libzpool2                                 x86_64                     0.7.12-1.el7_4                        zfs                                            594 k
 spl                                       x86_64                     0.7.12-1.el7_4                        zfs                                             29 k
 spl-dkms                                  noarch                     0.7.12-1.el7_4                        zfs                                            457 k
 zfs-dkms                                  noarch                     0.7.12-1.el7_4                        zfs                                            4.9 M
Updating for dependencies:
 elfutils                                  x86_64                     0.172-2.el7                           zfs                                            299 k
 elfutils-libelf                           x86_64                     0.172-2.el7                           zfs                                            194 k
 elfutils-libs                             x86_64                     0.172-2.el7                           zfs                                            285 k

Transaction Summary
```

通过`yum install`的输出可以看到相关依赖使用了本地的`zfs` Repository。

安装完成后验证：

```
[root@intel176 zfs-soft]# which zfs
/usr/sbin/zfs
```



#### 创建虚拟磁盘

因为175上没有空闲磁盘可供使用，所以采用虚拟磁盘的方式来进行验证。

```shell
mkdir /zfstest
cd /zfstest
dd if=/dev/zero of=disk1.img bs=4K count=2621440  #10GB 
losetup /dev/loop0 /zfstest/disk1.img
#mount /zfstest/disk1.img /zfs
#mount /dev/loop0 /zfs
```



#### 创建ZFS文件系统

```shell
zpool create -f zfstest1 /dev/loop0
zpool list 
zpool status
[root@intel175 zfstest1]# df -h|grep zfs
zfstest1        9.7G   13M  9.7G   1% /zfstest1
```

#### 设置压缩

```shell
zfs set compression=gzip zfstest1
zfs set atime=off zfstest1
zfs get compressratio zfstest1
zfs get all zfstest1

zfs create zfstest1/data1
zfs set compression=gzip zfstest1/data1
zfs get compressratio zfstest1/data1
zfs get all zfstest1/data1
```

#### 测试压缩文件

```shell
# 复制文件到zfs dataset：
cd /data/danghb/
cp customer.csv /zfstest1/data1/
# 两边的大小对比：
[root@intel175 data1]# du -sh /zfstest1/data1/customer.csv
11M     /zfstest1/data1/customer.csv
[root@intel175 data1]# du -sh /data/danghb/customer.csv
88M     /data/danghb/customer.csv
[root@intel175 data1]# zfs get compressratio zfstest1/data1
NAME            PROPERTY       VALUE  SOURCE
zfstest1/data1  compressratio  8.28x  -
```

压缩后的文件，通过` df -h`查看，大小为压缩后的大小,与`du`看到的一样：

```shell
[root@intel175 data1]# df -h|head -1;df -h|tail -1
Filesystem      Size  Used Avail Use% Mounted on
zfstest1/data1  9.7G   11M  9.7G   1% /zfstest1/data1
```

但是通过`ls` 查看，返回的是实际大小：

```shell
[root@intel175 data1]# ls -lh customer.csv 
-rw-r--r-- 1 root root 88M Jul 16 16:59 customer.csv
```

放了antdb的rpm包进去，发现二进制压缩不了：
```shell
[root@intel175 data1]# du -sh antdb-4.0.70477ffb-centos6.3.rpm 
 13M     antdb-4.0.70477ffb-centos6.3.rpm
```

压缩比是整个dataset的，放进去二进制后，压缩比变小了：

 ```shell
 [root@intel175 data1]# zfs get compressratio zfstest1/data1
 NAME            PROPERTY       VALUE  SOURCE
 zfstest1/data1  compressratio  4.34x  -
 ```

`antdb`单机版的二进制目录复制到zfs：

```shell
[root@intel175 app]# cp -R adb41_alone /zfstest1/data1/antdb/app/
[root@intel175 app]# du -sh adb41_alone
115M    adb41_alone
[root@intel175 app]# du -sh adb41_alone
41M     adb41_alone
```

`antdb`单机版的数据目录复制到zfs：

```shell
[root@intel175 data]# du -sh adb41_alone
746M    adb41_alone
# zfs
[root@intel175 data1]# du -sh adb41_alone
127M    adb41_alone
```

此时data1 目录的压缩率为：

```shell
[root@intel175 data1]# ll
total 1
drwxr-xr-x 4 root root 4 Jul 16 17:17 antdb
[root@intel175 data1]# zfs get compressratio zfstest1/data1
NAME            PROPERTY       VALUE  SOURCE
zfstest1/data1  compressratio  4.46x  -
```

###  pgbench测试

####  非zfs

```shell
[danghb@intel175 ~]$ pgbench -c 20 -j 20 -T 60  pgbench
starting vacuum...end.
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 100
query mode: simple
number of clients: 20
number of threads: 20
duration: 60 s
number of transactions actually processed: 902822
latency average = 1.329 ms
tps = 15046.616230 (including connections establishing)
tps = 15049.305580 (excluding connections establishing)
```

执行期间CPU：

```shell
----system---- ----total-cpu-usage---- -dsk/total- -net/total- ---paging-- ---system-- ------memory-usage----- ---load-avg---
     time     |usr sys idl wai hiq siq| read  writ| recv  send|  in   out | int   csw | used  buff  cach  free| 1m   5m  15m 
16-07 17:34:19|  8   1  91   0   0   0|   0   112k|6330B 5520B|   0     0 |  25k  129k|56.6G  427M 51.8G 1295M|5.37 3.62 1.81
16-07 17:34:20| 22   3  76   0   0   0|   0    12k| 855B  707B|   0     0 |  54k  460k|56.6G  427M 51.8G 1249M|5.98 3.78 1.87
16-07 17:34:21| 22   3  76   0   0   0|   0   284k|6155B 6191B|   0     0 |  54k  500k|56.6G  427M 51.8G 1237M|5.98 3.78 1.87
16-07 17:34:22| 22   2  76   0   0   0|   0    92k| 720B  705B|   0     0 |  52k  501k|56.6G  427M 51.8G 1218M|5.98 3.78 1.87
16-07 17:34:23| 22   2  76   0   0   0|   0    43M|4856B 5065B|   0     0 |  53k  510k|56.6G  427M 51.8G 1216M|5.98 3.78 1.87
16-07 17:34:24| 22   2  76   0   0   0|   0    44k|2784B 2249B|   0     0 |  53k  506k|56.6G  427M 51.9G 1197M|5.98 3.78 1.87
16-07 17:34:25| 22   2  76   0   0   0|   0   100k|6305B 5440B|   0     0 |  53k  502k|56.6G  427M 51.9G 1197M|7.02 4.03 1.97
16-07 17:34:26| 22   2  76   0   0   0|   0    10M|1326B 1213B|   0     0 |  55k  510k|56.6G  427M 51.9G 1180M|7.02 4.03 1.97
。。。
16-07 17:35:14| 22   3  74   2   0   0|4096B  113M|2272B 1699B|   0     0 |  79k  425k|56.6G  423M 51.9G 1146M|13.3 6.11 2.77
16-07 17:35:15| 22   2  76   0   0   0|   0   104k|8046B 5598B|   0     0 |  76k  411k|56.6G  423M 51.9G 1145M|13.8 6.32 2.85
16-07 17:35:16| 22   2  76   0   0   0|   0   240k|1225B 1194B|   0     0 |  75k  419k|56.6G  423M 51.9G 1130M|13.8 6.32 2.85
16-07 17:35:17| 22   2  76   0   0   0|   0    84k|4652B 5111B|   0     0 |  74k  403k|56.6G  423M 51.9G 1126M|13.8 6.32 2.85
16-07 17:35:18| 22   2  76   0   0   0|  52k  376k|2771B  740B|   0     0 |  74k  405k|56.6G  423M 51.9G 1126M|13.8 6.32 2.85
16-07 17:35:19| 15   3  82   0   0   0| 336k   96k|4913B 5620B|   0     0 |  55k  272k|56.5G  423M 51.9G 1185M|13.8 6.32 2.85
```



#### zfs

```shell
[danghb@intel175 adb41_alone]$ which pgbench
/zfstest1/data1/antdb/app/adb41_alone/bin/pgbench
[danghb@intel175 adb41_alone]$ pgbench -c 20 -j 20 -T 60  pgbench
starting vacuum...end.
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 100
query mode: simple
number of clients: 20
number of threads: 20
duration: 60 s
number of transactions actually processed: 856376
latency average = 1.401 ms
tps = 14272.607266 (including connections establishing)
tps = 14275.315602 (excluding connections establishing)
```

执行期间CPU：

```shell
[danghb@intel175 ~]$ dstat -taml
----system---- ----total-cpu-usage---- -dsk/total- -net/total- ---paging-- ---system-- ------memory-usage----- ---load-avg---
     time     |usr sys idl wai hiq siq| read  writ| recv  send|  in   out | int   csw | used  buff  cach  free| 1m   5m  15m 
16-07 17:36:37|  1   0  99   0   0   0|  32k  484k|   0     0 |   1B   37B|9913    13k|56.5G  419M 51.9G 1218M|4.57 5.05 2.69
16-07 17:36:38| 18   6  76   0   0   0|   0    36k|4919B 5399B|   0     0 |  56k  379k|56.6G  417M 51.9G 1213M|4.57 5.05 2.69
16-07 17:36:39| 18   8  73   0   0   0|5952k 7224k| 502B  290B|   0     0 |  58k  396k|56.5G  417M 52.0G 1193M|4.57 5.05 2.69
16-07 17:36:40| 19   5  76   0   0   0|   0   144k|4386B 4650B|   0     0 |  55k  412k|56.5G  416M 52.0G 1124M|5.32 5.20 2.75
16-07 17:36:41| 20   5  76   0   0   0|   0   148k| 396B  290B|   0  8192B|  57k  421k|56.5G  414M 51.9G 1215M|5.32 5.20 2.75
16-07 17:36:42| 20   4  76   0   0   0|   0    60k|4704B 4724B|   0     0 |  54k  430k|56.5G  413M 51.9G 1214M|5.32 5.20 2.75
16-07 17:36:43| 20   4  76   0   0   0|   0    84k|2302B 1104B|   0     0 |  55k  430k|56.5G  411M 51.9G 1229M|5.32 5.20 2.75
16-07 17:36:44| 20   9  70   0   0   0|  11M   13M|4712B 4716B|   0     0 |  64k  424k|56.5G  411M 52.0G 1223M|5.32 5.20 2.75
16-07 17:36:45| 20   4  76   0   0   0|   0  4096B| 506B  954B|   0     0 |  56k  437k|56.5G  409M 51.9G 1286M|6.34 5.41 2.83
16-07 17:36:46| 20   4  76   0   0   0|   0   432k|5512B 5289B|   0     0 |  55k  435k|56.5G  408M 51.8G 1318M|6.34 5.41 2.83
16-07 17:36:47| 21   3  76   0   0   0|   0   492k| 684B  290B|   0     0 |  58k  449k|56.5G  406M 51.8G 1374M|6.34 5.41 2.83
16-07 17:36:48| 21   3  76   0   0   0|   0   296k|5246B 4922B|   0     0 |  55k  439k|56.5G  406M 51.8G 1328M|6.34 5.41 2.83
16-07 17:36:49| 20   8  71   0   0   0|  11M   13M|1632B  290B|   0     0 |  66k  444k|56.5G  406M 51.9G 1316M|6.34 5.41 2.83
16-07 17:36:50| 21   3  76   0   0   0|   0    92k|4206B 4650B|   0     0 |  54k  462k|56.5G  404M 51.8G 1366M|7.35 5.64 2.92
16-07 17:36:51| 21   3  76   0   0   0|   0    56k| 786B  290B|   0     0 |  56k  462k|56.5G  401M 51.7G 1449M|7.35 5.64 2.92
16-07 17:36:52| 21   3  76   0   0   0|   0    40k|4446B 4724B|   0     0 |  55k  455k|56.5G  400M 51.7G 1495M|7.35 5.64 2.92
16-07 17:36:53| 21   3  75   0   0   0|   0   152k|1808B 1481B|   0     0 |  62k  451k|56.6G  399M 51.6G 1515M|7.35 5.64 2.92
16-07 17:36:54| 21   8  70   0   0   0|  11M   13M|4954B 5090B|   0     0 |  70k  460k|56.5G  399M 51.6G 1552M|7.35 5.64 2.92
16-07 17:36:55| 21   3  76   0   0   0|   0    52k|1393B 1162B|   0     0 |  63k  454k|56.5G  398M 51.6G 1509M|7.96 5.79 2.98
16-07 17:36:56| 21   3  76   0   0   0|   0   248k|6124B 5022B|   0     0 |  61k  445k|56.6G  398M 51.6G 1494M|7.96 5.79 2.98
16-07 17:36:57| 21   3  76   0   0   0|   0    28k| 568B  658B|   0     0 |  67k  448k|56.6G  397M 51.6G 1529M|7.96 5.79 2.98
16-07 17:36:58| 21   3  76   0   0   0|   0    36k|6801B 5218B|   0     0 |  65k  453k|56.6G  394M 51.5G 1613M|7.96 5.79 2.98
16-07 17:36:59| 21   8  70   0   0   0|  11M   13M|2579B   17k|   0     0 |  79k  451k|56.5G  394M 51.5G 1650M|7.96 5.79 2.98
16-07 17:37:00| 21   3  76   0   0   0|   0    20k|5536B 5485B|   0     0 |  58k  480k|56.6G  393M 51.5G 1658M|8.69 5.98 3.06
16-07 17:37:01| 22   3  76   0   0   0|   0    56k|3215B 1830B|   0     0 |  55k  479k|56.6G  393M 51.5G 1669M|8.69 5.98 3.06
...
16-07 17:37:25| 22   2  76   0   0   0|   0    16k|2002B 1605B|   0     0 |  73k  468k|56.7G  383M 51.2G 1876M|10.5 6.65 3.36
16-07 17:37:26| 22   2  76   0   0   0|   0   220k|5700B 5464B|   0     0 |  76k  456k|56.7G  383M 51.2G 1853M|10.5 6.65 3.36
16-07 17:37:27| 22   2  76   0   0   0|   0    88k|1764B 1039B|   0     0 |  77k  456k|56.7G  383M 51.2G 1850M|10.5 6.65 3.36
16-07 17:37:28| 22   3  75   0   0   0|   0  5284k|6189B 5619B|   0  5212k|  95k  462k|56.6G  277M 49.7G 3520M|10.5 6.65 3.36
16-07 17:37:29| 22   7  71   0   0   0|  11M   13M|1732B 1057B|   0     0 |  85k  460k|56.6G  277M 49.7G 3527M|10.5 6.65 3.36
16-07 17:37:30| 22   2  76   0   0   0|8192B   68k|7445B 5474B|   0     0 |  77k  469k|56.6G  277M 49.7G 3498M|11.1 6.84 3.44
16-07 17:37:31| 22   2  76   0   0   0|   0    56k|1325B 1039B|   0     0 |  76k  473k|56.6G  277M 49.7G 3494M|11.1 6.84 3.44
16-07 17:37:32| 22   2  76   0   0   0|   0   272k|5577B 5403B|   0     0 |  74k  453k|56.7G  277M 49.7G 3469M|11.1 6.84 3.44
16-07 17:37:33| 22   2  76   0   0   0|   0    12k|4791B 1859B|   0     0 |  73k  455k|56.7G  277M 49.7G 3467M|11.1 6.84 3.44
16-07 17:37:34| 21   8  71   0   0   0|  11M   13M|5108B 5416B|   0     0 |  78k  444k|56.7G  277M 49.7G 3460M|11.1 6.84 3.44
16-07 17:37:35| 18   6  77   0   0   0|   0   164k|1841B 2394B|   0     0 |  73k  373k|56.6G  277M 49.7G 3538M|10.2 6.72 3.42
16-07 17:37:36|  1   0  99   0   0   0|   0   188k|7081B 5473B|   0     0 |  12k   15k|56.6G  277M 49.7G 3542M|10.2 6.72 3.42
16-07 17:37:37|  1   0  98   0   0   0|4096B  440k| 605B  669B|   0     0 |  12k   15k|56.6G  277M 49.7G 3543M|10.2 6.72 3.42
```

#### 两个对比：

```
2019-07-16 17:55:55 antdb41 at normal fs
tps = 31752.860849 (including connections establishing)
tps = 32491.999660 (including connections establishing)
tps = 31445.636173 (including connections establishing)
tps = 31634.372200 (including connections establishing)
tps = 32015.013171 (including connections establishing)
tps = 31373.589055 (including connections establishing)
tps = 32645.347840 (including connections establishing)
tps = 31714.821882 (including connections establishing)
tps = 31871.598784 (including connections establishing)
tps = 32931.662414 (including connections establishing)
2019-07-16 18:25:57 antdb41 at zfs fs
tps = 32361.109291 (including connections establishing)
tps = 31942.444442 (including connections establishing)
tps = 32162.858790 (including connections establishing)
tps = 31989.088504 (including connections establishing)
tps = 31789.771467 (including connections establishing)
tps = 31571.793157 (including connections establishing)
tps = 32099.231762 (including connections establishing)
tps = 31831.781732 (including connections establishing)
tps = 31468.254495 (including connections establishing)
tps = 31625.083693 (including connections establishing)
```

从结果看，

### 参考链接

- https://linux.cn/article-10034-1.html   初学者指南：ZFS 是什么，为什么要使用 ZFS？ 
- https://wiki.archlinux.org/index.php/ZFS   
- http://server.it168.com/a2011/0306/1162/000001162962_all.shtml  Linux服务器ZFS文件系统使用攻略 
- https://www.oschina.net/news/103578/zfs-on-linux-5-0-problem  ZFS On Linux 在 Linux Kernel 5.0 上陷入了困境… 
- https://www.linuxprobe.com/centos7-install-use-zfs.html   如何在Centos7上安装和使用ZFS 
- https://www.symmcom.com/docs/how-tos/storages/how-to-install-zfs-on-centos-7   How To Install ZFS on CentOS 7 
- https://linuxhint.com/install-zfs-centos7/   Install ZFS on CentOS7 
- https://github.com/zfsonlinux/zfs/wiki/RHEL-and-CentOS  
- https://www.oschina.net/translate/running-postgresql-on-compression-enabled-zfs  在启用压缩的 ZFS 上运行 PostgreSQL
- https://postgres.fun/20140710114452.html ZFS: 关于压缩(Compression)
- https://pthree.org/2012/12/18/zfs-administration-part-xi-compression-and-deduplication/  Compression and Deduplication
- https://wiki.archlinux.org/index.php/ZFS#Automatic_Start  zfs自启动
- https://blog.csdn.net/lanjianhun/article/details/69360406  yum安装本地rpm软件



