#  AntDB 单机版本安装postgis

## 前置条件

* AntDB 已经安装完成，相关环境变量也配置完成，可以通过 `which pg_config` 找到AntDB程序目录下的`pg_config`
* 建议通过操作系统的安装镜像配置本地yum源。

## 选择postgis与postgresql的版本对应关系

从 http://trac.osgeo.org/postgis/wiki/UsersWikiPostgreSQLPostGIS 这个链接获取两者的版本对应关系。AntDB 最新单机版本基于PG11，所以可以选择postgis 2.4或者2.5，本例选择postgis2.5.

| **PostgreSQL version** | **PostGIS 1.3 EOL** | **PostGIS 1.4 EOL** | **PostGIS 1.5 EOL**   | **PostGIS 2.0 EOL**   | **PostGIS 2.1 EOL**   | **PostGIS 2.2 EOL**   | **PostGIS 2.3**        | **PostGIS 2.4** | **PostGIS 2.5** | **PostGIS 3.0 (Trunk)** |
| ---------------------- | ------------------- | ------------------- | --------------------- | --------------------- | --------------------- | --------------------- | ---------------------- | --------------- | --------------- | ----------------------- |
| PostGIS release date   | 2007/08/09          | 2009/07/24          | 2010/02/04            | 2012/04/03            | 2013/08/17            | 2015/10/07            | 2016/09/26             | 2017/09/30      | 2018/09/23      | 2019/xx/xx              |
| **12**                 | No                  | No                  | No                    | No                    | No                    | No                    | No                     | No              | **No\***        | **Yes**                 |
| **11**                 | No                  | No                  | No                    | No                    | No                    | No                    | No                     | Yes*            | **Yes**         | **Yes**                 |
| **10**                 | No                  | No                  | No                    | No                    | No                    | No                    | Yes (not recommended)) | **Yes**         | **Yes**         | **Yes**                 |
| **9.6**                | No                  | No                  | No                    | No                    | No                    | Yes (not recommended) | **Yes**                | **Yes**         | **Yes**         | **Yes**                 |
| **9.5**                | No                  | No                  | No                    | No                    | No                    | **Yes**               | **Yes**                | **Yes**         | **Yes**         | Yes                     |
| **9.4**                | No                  | No                  | No                    | No                    | Yes                   | **Yes**               | **Yes**                | **Yes**         | **Yes**         | No                      |
| **9.3 EOL**            | No                  | No                  | No                    | No                    | Yes                   | Yes                   | Yes                    | Yes             | No              | No                      |
| **9.2 EOL**            | No                  | No                  | Yes (not recommended) | Yes                   | Yes                   | Yes                   | Yes                    | No              | No              | No                      |
| **9.1 EOL**            | No                  | No                  | Yes                   | Yes                   | Yes                   | Yes                   | No                     | No              | No              | No                      |
| **9.0 EOL**            | No                  | No                  | Yes                   | Yes (not recommended) | Yes (not recommended) | No                    | No                     | No              | No              | No                      |
| **8.4 EOL**            | Yes                 | Yes                 | Yes                   | Yes (not recommended) | No                    | No                    | No                     | No              | No              | No                      |
| **8.3 EOL**            | Yes                 | Yes                 | Yes                   | No                    | No                    | No                    | No                     | No              | No              | No                      |
| **8.2 EOL**            | Yes                 | Yes                 | No                    | No                    | No                    | No                    | No                     | No              | No              | No                      |
| **8.1 EOL**            | Yes                 | No                  | No                    | No                    | No                    | No                    | No                     | No              | No              | No                      |
| **8.0 EOL**            | Yes (not windows)   | No                  | No                    | No                    | No                    | No                    | No                     | No              | No              | No                      |
| **7.2-7.4 EOL**        | Yes (not windows)   | No                  | No                    | No                    | No                    | No                    | No                     | No              | No              | No                      |

## 在线安装依赖

官方列出的依赖包括：

- postgtesql V9.4+
- gcc 
- gmake or make
- Proj4 V4.9+
- GEOS V3.5+
- LibXML2 V2.5+
- JSON-C V0.9+
- GDAL V1.8+
- SFCGAL V1.1+

分别进行安装，本例中通过yum 在线安装：

```
sudo yum install -y libxml2
sudo yum install -y libxml2-devel
sudo yum install -y json-c
sudo yum install -y json-c-devel
sudo yum install -y proj
sudo yum install -y proj-devel
sudo yum install -y gdal
sudo yum install -y gdal-devel
sudo yum install -y geos
sudo yum install -y geos-devel
sudo yum install -y  SFCGAL
sudo yum install -y  SFCGAL-devel
```

> 如果可以的话，建议在yum 源中增加epel的源，可以在线安装很多软件。
>
> 如果是离线环境，则需要根据https://postgis.net/docs/manual-2.5/postgis_installation.html 中的说明，提前下载好对应组件的源码。

当前yum源安装proj 为V4.8,不满足安装要求，故proj采用源码编译的方式进行安装:

```
wget http://download.osgeo.org/proj/proj-4.9.1.tar.gz
tar -xvzf proj-4.9.1.tar.gz
cd proj-4.9.1
./configure --prefix=/usr/local/proj
make  -j8
sudo make install

[antdb@host]$ proj
Rel. 4.9.1, 04 March 2015
usage: proj [ -beEfiIlormsStTvVwW [args] ] [ +opts[=arg] ] [ files ]
```

## 离线安装依赖
在生产网络的离线环境中，依赖需要通过源码编译的方式进行安装。    
依赖组件的版本均选择当前发布的**次新**版本。    


### cmake
因源码编译安装组件的时候需要依赖cmake，且操作系统自带的cmake版本较低，因此通过源码编译的方式安装高版本的cmake。

下载源码：wget https://cmake.org/files/v3.17/cmake-3.17.2.tar.gz

源码安装：
```shell
tar xzvf cmake-3.17.2.tar.gz && cd cmake-3.17.2 && ./configure && gmake -j10 && sudo gmake install && cd ..
```

安装完成后，通过`cmake -version` 检查当前版本是否正确，应该为：`3.17.2`。


### json-c

下载源码：wget https://github.com/json-c/json-c/archive/json-c-0.14-20200419.zip

源码安装：
```shell
unzip json-c-0.14-20200419.zip && cd json-c-json-c-0.14-20200419 && cmake . && make && sudo make install && cd ..
```


### CGAL

下载源码：wget https://github.com/CGAL/cgal/releases/download/releases%2FCGAL-4.14.3/CGAL-4.14.3.zip



cgal 需要依赖`boost`、`mpfr`、`gmp`，可以通过操作系统镜像自带的yum源安装：

```shell
sudo yum install -y boost
sudo yum install -y mpfr
sudo yum install -y gmp
sudo yum install -y boost-devel
sudo yum install -y mpfr-devel
sudo yum install -y gmp-devel

```

源码安装：
```shell
unzip CGAL-4.14.3.zip && cd CGAL-4.14.3 && cmake -DCGAL_HEADER_ONLY=OFF -DCMAKE_BUILD_TYPE=Release . && make && sudo make install && cd ..
```  

### proj

下载源码：wget http://download.osgeo.org/proj/proj-4.9.1.tar.gz


源码安装：
```shell
tar -xvzf proj-4.9.1.tar.gz
cd proj-4.9.1
./configure
make  -j8
sudo make install
```

安装完成后， 执行 `proj` 是否安装成功，正确输出应该为：

```
Rel. 4.9.1, 04 March 2015
usage: proj [ -beEfiIlormsStTvVwW [args] ] [ +opts[=arg] ] [ files ]
```

### gdal

下载源码：wget http://download.osgeo.org/gdal/2.4.3/gdal-2.4.3.tar.gz

源码安装：
```shell
tar -xzvf gdal-2.4.3.tar.gz
cd gdal-2.4.3
./configure --with-pg=/data/antdb/app/bin/pg_config
make  -j8
sudo make install
```

安装完成后， 执行 `gdal-config --version` 是否安装成功，正确输出应该为：

```
2.4.3
```


编译的时候，需要指定pg_config的绝对路径，`pg_config` 需要选择AntDB的路径，而不是操作系统自带的`pg_config`。     
`pg_config` 的路径一般在 `$ADB_HOME/bin`  。

### geos

下载源码：wget http://download.osgeo.org/geos/geos-3.7.3.tar.bz2

源码安装：
```shell
tar -jxvf geos-3.7.3.tar.bz2
cd geos-3.5.2
./configure
make  -j8
sudo make install
```

> 若解压失败，可能需要安装 `bzip2`: sudo yum install bzip2


安装完成后， 执行 `geos-config --version` 是否安装成功，正确输出应该为：

```
3.7.3
```


### SFCGAL

下载源码： wget https://github.com/Oslandia/SFCGAL/archive/v1.3.7.zip

SFCGAL  本身还需要依赖如下：
* cgal
* boost
* mpfr
* gmp

其中 `cgal` 前面已经通过源码安装。`boost`、`mpfr`、`gmp` 可以通过操作系统镜像自带的yum源安装：

> 如果前面CGAL安装成功，则这些依赖都已经安装。


```shell
sudo yum install -y boost
sudo yum install -y mpfr
sudo yum install -y gmp
sudo yum install -y boost-devel
sudo yum install -y mpfr-devel
sudo yum install -y gmp-devel
```

源码安装 SFCGAL:

```shell
unzip SFCGAL-v1.3.7.zip && cd SFCGAL-1.3.7 && cmake . && make && sudo make install &&  cd ..
```

创建软链接：
```
sudo ln -s  /usr/local/lib64/libSFCGAL.so /usr/local/lib/libSFCGAL.so
```

安装完成后， 执行 `sfcgal-config --version` 是否安装成功，正确输出应该为：

```
1.3.7
```

依赖安装完成之后，修改 /etc/ld.so.conf 文件，增加两行内容：
```
/usr/local/lib
/usr/local/lib64
```
保存后，执行 `sudo ldconfig -v`。


以上依赖的源码包也可以在地址： http://120.55.76.224/files/postgis/ 找到。


注意：**一主多从环境中，以上组件需要在所有的主机上都进行安装！，否则在节点发生切换后，可能引起gis功能异常。**

###  postgis

* 下载源码

```
wget http://postgis.net/stuff/postgis-2.5.4.tar.gz
tar -xvzf postgis-2.5.4.tar.gz
```

*  编译

```
cd postgis-2.5.4
./configure  --with-pgconfig=/data/antdb/app/bin/pg_config --with-sfcgal=/usr/local/bin/sfcgal-config
```

> `pg_config`和`sfcgal-config`的路径需要根据实际情况进行替换。


编译成功后，会打印如下信息：
```
PostGIS is now configured for x86_64-unknown-linux-gnu

 -------------- Compiler Info ------------- 
  C compiler:           gcc -g -O2
  SQL preprocessor:     /bin/cpp -traditional-cpp -w -P

 -------------- Additional Info ------------- 
  Interrupt Tests:   DISABLED use: --with-interrupt-tests to enable

 -------------- Dependencies -------------- 
  GEOS config:          /usr/local/bin/geos-config
  GEOS version:         3.7.3
  GDAL config:          /usr/local/bin/gdal-config
  GDAL version:         2.4.1
  SFCGAL config:        /usr/local/bin/sfcgal-config
  SFCGAL version:       1.3.7
  PostgreSQL config:    /data/antdb/app/bin/pg_config
  PostgreSQL version:   PostgreSQL 11.6
  PROJ4 version:        49
  Libxml2 config:       /bin/xml2-config
  Libxml2 version:      2.9.1
  JSON-C support:       yes
  protobuf-c support:   no
  PCRE support:         yes
  Perl:                 /bin/perl

 --------------- Extensions --------------- 
  PostGIS Raster:       enabled
  PostGIS Topology:     enabled
  SFCGAL support:       enabled
  Address Standardizer support:       enabled

 -------- Documentation Generation -------- 
  xsltproc:             /bin/xsltproc
  xsl style sheets:     
  dblatex:              
  convert:              
  mathml2.dtd:          http://www.w3.org/Math/DTD/mathml2/mathml2.dtd

```

*  安装

```
make
```

make成功后，最后一行信息为：

```
PostGIS was built successfully. Ready to install.
```

执行 ：

```
sudo make install
```


### pgrouting（可选）
pgrouting的依赖如下：
* C and C++0x compilers * g++ version >= 4.8
* Postgresql version >= 9.3
* PostGIS version >= 2.2
* The Boost Graph Library (BGL). Version >= 1.53
* CMake >= 3.2
* CGAL >= 4.2

下载源码：wget https://github.com/pgRouting/pgrouting/archive/v2.6.3.tar.gz
源码安装：
```shell
tar xzvf pgrouting-2.6.3.tar.gz
cd pgrouting-2.6.3
mkdir build
cd build
cmake  -DPOSTGRESQL_PG_CONFIG=/data/antdb/app/bin/pg_config -DPOSTGRESQL_INCLUDE_DIR=/data/antdb/app/include/postgresql/server ..
make
make install
```

> `DPOSTGRESQL_PG_CONFIG`和`POSTGRESQL_INCLUDE_DIR` 参数值根据实际AntDB的安装路径修改。


### 检查so文件的依赖

```
find  $ADB_HOME -name 'postgis*so'
```

期望的输出为：
```
/data/antdb/app/lib/postgresql/postgis_topology-2.5.so
/data/antdb/app/lib/postgresql/postgis-2.5.so
```

检查postgis 库文件的依赖：

```
ldd /data/antdb/app/lib/postgresql/postgis-2.5.so
```

期望的输出为：
```
        linux-vdso.so.1 =>  (0x00007ffc87dd2000)
        libgeos_c.so.1 => /usr/local/lib/libgeos_c.so.1 (0x00007faa7d95b000)
        libproj.so.9 => /usr/local/lib/libproj.so.9 (0x00007faa7d6fd000)
        libjson-c.so.5 => /usr/local/lib64/libjson-c.so.5 (0x00007faa7d4e9000)
        libxml2.so.2 => /lib64/libxml2.so.2 (0x00007faa7d16d000)
        libm.so.6 => /lib64/libm.so.6 (0x00007faa7ce6a000)
        libSFCGAL.so.1 => /usr/local/lib64/libSFCGAL.so.1 (0x00007faa7c305000)
        libc.so.6 => /lib64/libc.so.6 (0x00007faa7bf38000)
        libgeos-3.7.3.so => /usr/local/lib/libgeos-3.7.3.so (0x00007faa7bb86000)
        libstdc++.so.6 => /lib64/libstdc++.so.6 (0x00007faa7b87f000)
        libgcc_s.so.1 => /lib64/libgcc_s.so.1 (0x00007faa7b669000)
        libpthread.so.0 => /lib64/libpthread.so.0 (0x00007faa7b44c000)
        /lib64/ld-linux-x86-64.so.2 (0x00007faa7de4f000)
        libdl.so.2 => /lib64/libdl.so.2 (0x00007faa7b248000)
        libz.so.1 => /lib64/libz.so.1 (0x00007faa7b032000)
        liblzma.so.5 => /lib64/liblzma.so.5 (0x00007faa7ae0b000)
        libCGAL_Core.so.13 => /usr/local/lib64/libCGAL_Core.so.13 (0x00007faa7ab32000)
        libboost_thread-mt.so.1.53.0 => /lib64/libboost_thread-mt.so.1.53.0 (0x00007faa7a91b000)
        libboost_system-mt.so.1.53.0 => /lib64/libboost_system-mt.so.1.53.0 (0x00007faa7a716000)
        libboost_serialization-mt.so.1.53.0 => /lib64/libboost_serialization-mt.so.1.53.0 (0x00007faa7a4aa000)
        libboost_chrono-mt.so.1.53.0 => /lib64/libboost_chrono-mt.so.1.53.0 (0x00007faa7a2a2000)
        libboost_date_time-mt.so.1.53.0 => /lib64/libboost_date_time-mt.so.1.53.0 (0x00007faa7a090000)
        libboost_atomic-mt.so.1.53.0 => /lib64/libboost_atomic-mt.so.1.53.0 (0x00007faa79e8e000)
        libCGAL.so.13 => /usr/local/lib64/libCGAL.so.13 (0x00007faa79c62000)
        libmpfr.so.4 => /lib64/libmpfr.so.4 (0x00007faa79a06000)
        libgmp.so.10 => /lib64/libgmp.so.10 (0x00007faa7978e000)
        librt.so.1 => /lib64/librt.so.1 (0x00007faa79585000)
```

注意：**postgis和pgrouting安装成功后，在一主多从环境中，需要把$ADB_HOME 复制到其他主机上，否则节点发生切换后，可能引起gis功能异常。**

安装完成后，将antdb重启，以便数据库进程可以加载新的环境变量和动态库。

## 登录AntDB创建扩展

执行如下语句：

```
SELECT name, default_version,installed_version
FROM pg_available_extensions WHERE name LIKE 'postgis%' or name LIKE 'address%';
```

预期的返回结果为：

```
             name             | default_version | installed_version 
------------------------------+-----------------+-------------------
 postgis_tiger_geocoder       | 2.5.3           | 
 address_standardizer_data_us | 2.5.3           | 
 postgis                      | 2.5.3           | 
 postgis_sfcgal               | 2.5.3           | 
 address_standardizer         | 2.5.3           | 
 postgis_topology             | 2.5.3           | 
(6 rows)
```

创建extension：

```
CREATE EXTENSION postgis;
CREATE EXTENSION postgis_sfcgal;
CREATE EXTENSION fuzzystrmatch; 
CREATE EXTENSION address_standardizer;
CREATE EXTENSION address_standardizer_data_us;
CREATE EXTENSION postgis_tiger_geocoder;
CREATE EXTENSION postgis_topology;
CREATE EXTENSION pgrouting;
```

再次执行检查语句：

```
select extname,extversion from pg_extension;
          extname            | extversion 
------------------------------+------------
 plpgsql                      | 1.0
 plorasql                     | 1.0
 postgis                      | 2.5.4
 fuzzystrmatch                | 1.1
 address_standardizer         | 2.5.4
 address_standardizer_data_us | 2.5.4
 pgrouting                    | 2.6.3
 postgis_tiger_geocoder       | 2.5.4
 postgis_sfcgal               | 2.5.4
 postgis_topology             | 2.5.4
```

至此，postgis 安装完成。

##  可能碰到的问题

### libproj.so.9: cannot open shared object file: No such file or directory

检查libproj.so.9的位置：

```
sudo find / -name 'libproj.so.9'
```

将libproj.so.9所在的目录加载的环境变量 LD_LIBRARY_PATH 中:

```
export LD_LIBRARY_PATH=$PGHOME/lib:$LD_LIBRARY_PATH:/usr/local/lib/
```

查看 postgis2.5.so的库依赖：

```
ldd /data/antdb/app/antdb/lib/postgresql/postgis-2.5.so
        linux-vdso.so.1 =>  (0x00007ffea2453000)
        libgeos_c.so.1 => /usr/geos37/lib64/libgeos_c.so.1 (0x00007fed18b85000)
        libproj.so.9 => /usr/local/lib/libproj.so.9 (0x00007fed18928000)
        libjson-c.so.2 => /lib64/libjson-c.so.2 (0x00007fed1871d000)
        libxml2.so.2 => /lib64/libxml2.so.2 (0x00007fed183b3000)
        libm.so.6 => /lib64/libm.so.6 (0x00007fed180b1000)
        libSFCGAL.so.1 => /lib64/libSFCGAL.so.1 (0x00007fed175ee000)
        libc.so.6 => /lib64/libc.so.6 (0x00007fed17221000)
        libgeos-3.7.1.so => /usr/geos37/lib64/libgeos-3.7.1.so (0x00007fed16e70000)
        libstdc++.so.6 => /lib64/libstdc++.so.6 (0x00007fed16b69000)
        libgcc_s.so.1 => /lib64/libgcc_s.so.1 (0x00007fed16953000)
        libpthread.so.0 => /lib64/libpthread.so.0 (0x00007fed16737000)
        libdl.so.2 => /lib64/libdl.so.2 (0x00007fed16533000)
        libz.so.1 => /lib64/libz.so.1 (0x00007fed1631d000)
        liblzma.so.5 => /lib64/liblzma.so.5 (0x00007fed160f7000)
        /lib64/ld-linux-x86-64.so.2 (0x00007fed19078000)
        libCGAL.so.11 => /usr/lib64/libCGAL.so.11 (0x00007fed15ecf000)
        libCGAL_Core.so.11 => /usr/lib64/libCGAL_Core.so.11 (0x00007fed15c96000)
        libmpfr.so.4 => /usr/lib64/libmpfr.so.4 (0x00007fed15a3b000)
        libgmp.so.10 => /usr/lib64/libgmp.so.10 (0x00007fed157c3000)
        libboost_date_time-mt.so.1.53.0 => /usr/lib64/libboost_date_time-mt.so.1.53.0 (0x00007fed155b2000)
        libboost_thread-mt.so.1.53.0 => /usr/lib64/libboost_thread-mt.so.1.53.0 (0x00007fed1539b000)
        libboost_system-mt.so.1.53.0 => /usr/lib64/libboost_system-mt.so.1.53.0 (0x00007fed15197000)
        libboost_serialization-mt.so.1.53.0 => /usr/lib64/libboost_serialization-mt.so.1.53.0 (0x00007fed14f2b000)
        librt.so.1 => /usr/lib64/librt.so.1 (0x00007fed14d23000)
```

输出正确后，当前登录信息退出后重新登录，并把antdb重启下。

### CMake 3.2 or higher is required.  You are running version 2.8.12.2
通过源码安装更高版本的cmake，并加载到环境变量`$PATH`中。

#### htup_details.h: No such file or directory
config的时候指定pg_config 已经include路径：
```
cmake  -DPOSTGRESQL_PG_CONFIG=/data/antdb/app/bin/pg_config -DPOSTGRESQL_INCLUDE_DIR=/data/antdb/app/include/postgresql/server ..
```


### /usr/local/lib/libSFCGAL.so: No such file or directory

libSFCGAL.so  在lib64 路径下:`/usr/local/lib64/libSFCGAL.so`,可以在lib下创建软链接:    
```
sudo ln -s  /usr/local/lib64/libSFCGAL.so /usr/local/lib/libSFCGAL.so
```


## 参考链接：

- https://postgis.net/docs/manual-2.5/postgis_installation.html 
- http://trac.osgeo.org/postgis/wiki/UsersWikiPostgreSQLPostGIS