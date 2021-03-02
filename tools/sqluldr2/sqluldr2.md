

### 介绍
sqluldr2是一款Oracle数据快速导出工具，包含32、64位程序，sqluldr2在大数据量导出方面速度超快，能导出亿级数据为excel文件，另外它的导入速度也是非常快速，功能是将数据以TXT/CSV等格式导出。

### 路径
云信库：AntDB/工具包/sqluldr2.zip

### 依赖
依赖oracle客户端
注：instantclient_11_2/libclntsh.so.11.1 复制为libclntsh.so.10.1

### 安装
#### 包名：sqluldr2.zip
解压后直接使用：
目录结构：
```shell
-rwx------ 1 antdb ai 214016 Mar 13  2013 sqluldr264.exe
-rwx------ 1 antdb ai 179200 Mar 13  2013 sqluldr2.exe
-rwx------ 1 antdb ai 155171 Mar 13  2013 sqluldr2_linux32_10204.bin
-rwx------ 1 antdb ai 185766 Mar 13  2013 sqluldr2_linux64_10204.bin
```
#### 命令介绍
```shell
[antdb@hn-zz-almdb01 oracle_exp]$ ./sqluldr2_linux64_10204.bin --help

SQL*UnLoader: Fast Oracle Text Unloader (GZIP, Parallel), Release 4.0.1
(@) Copyright Lou Fangxin (AnySQL.net) 2004 - 2010, all rights reserved.

License: Free for non-commercial useage, else 100 USD per server.

Usage: SQLULDR2 keyword=value [,keyword=value,...]

Valid Keywords:
   user    = username/password@tnsname
   sql     = SQL file name
   query   = select statement
   field   = separator string between fields
   record  = separator string between records
   rows    = print progress for every given rows (default, 1000000) 
   file    = output file name(default: uldrdata.txt)
   log     = log file name, prefix with + to append mode
   fast    = auto tuning the session level parameters(YES)
   text    = output type (MYSQL, CSV, MYSQLINS, ORACLEINS, FORM, SEARCH).
   charset = character set name of the target database.
   ncharset= national character set name of the target database.
   parfile = read command option from parameter file 

  for field and record, you can use '0x' to specify hex character code,
  \r=0x0d \n=0x0a |=0x7c ,=0x2c, \t=0x09, :=0x3a, #=0x23, "=0x22 '=0x27
```

  ### 使用
  例子：
  ```shell
  /opt/sqluldr2/sqluldr2_linux64_10204.bin user/password@ip:port/dbname ESCAPE='\' ESCF=',' ESCT=',' field=',' query="select * from tablename" file=/opt/out/tablename.txt log=/opt/out/tablename.log
  ```
  分析：
  ESCAPE、ESCF、ESCT同时使用，可对数据中指定字符进行转移（比如：ESCAPE='\' ESCF=',' ESCT=',' ；就是把‘,’替换为‘\,’，并为转义符转义。
  ESCAPE：转义符。
  ESCF：要转义的字符。
  ESCT：转义后的字符。

  导出的文件可以通过copy from导入到AntDB

  ### 异常处理
  1.一般默认换行符为每行数据的分隔符，但当数据中包含换行符时，会出现异常，导致copy时失败
    解决方法：通过sed替换掉数据库中的换行符为字符串\n（copy会把字符串\n解析为换行符），替换前需要把数据行的间隔符置指定其他字符（通过record参数），替换后再把数据行的间隔符替换为普通换行。
