#### fio 使用说明

fio用于在现场测试磁盘性能。

下载地址：http://freshmeat.sourceforge.net/projects/fio/

##### 安装fio

```
tar xzvf fio-2.1.10.tar.gz
cd fio-2.1.10
./configure 
sudo make install
```

验证安装

```
[danghb@intel175 fio-2.1.10]$ which fio
/usr/local/bin/fio
[danghb@intel175 fio-2.1.10]$ fio --help
fio-2.1.10
fio [options] [job options] <job file(s)>
  --debug=options       Enable debug logging. May be one/more of:
                        process,file,io,mem,blktrace,verify,random,parse,
                        diskutil,job,mutex,profile,time,net,rate
  --parse-only          Parse options only, don't start any IO
  --output              Write output to file
  --runtime             Runtime in seconds
  --latency-log         Generate per-job latency logs
  --bandwidth-log       Generate per-job bandwidth logs
  --minimal             Minimal (terse) output
  --output-format=x     Output format (terse,json,normal)
  --terse-version=x     Set terse version output format to 'x'
  --version             Print version info and exit
  --help                Print this page
  --cpuclock-test       Perform test/validation of CPU clock
  --crctest             Test speed of checksum functions
  --cmdhelp=cmd         Print command help, "all" for all of them
  --enghelp=engine      Print ioengine help, or list available ioengines
  --enghelp=engine,cmd  Print help for an ioengine cmd
  --showcmd             Turn a job file into command line options
  --eta=when            When ETA estimate should be printed
                        May be "always", "never" or "auto"
  --eta-newline=time    Force a new line for every 'time' period passed
  --status-interval=t   Force full status dump every 't' period passed
  --readonly            Turn on safety read-only checks, preventing writes
  --section=name        Only run specified section in job file
  --alloc-size=kb       Set smalloc pool to this size in kb (def 1024)
  --warnings-fatal      Fio parser warnings are fatal
  --max-jobs=nr         Maximum number of threads/processes to support
  --server=args         Start a backend fio server
  --daemonize=pidfile   Background fio server, write pid to file
  --client=hostname     Talk to remote backend fio server at hostname
  --idle-prof=option    Report cpu idleness on a system or percpu basis
                        (option=system,percpu) or run unit work
                        calibration only (option=calibrate)

Fio was written by Jens Axboe <jens.axboe@oracle.com>
                   Jens Axboe <jaxboe@fusionio.com>
                   Jens Axboe <axboe@fb.com>
```



##### 执行fio测试

可以使用之前写的脚本：

```shell
#!/bin/bash

function usage()
{
    echo "sh $0 datadir runtime filesize"
}


function exe_fio_r_w()
{
    testname=$1
    if [ "$testname" == "randread" ];then
        iotype="randread"
    elif [ "$testname" == "seq_read" ];then
        iotype="read"
    elif [ "$testname" == "seq_write" ];then
        iotype="write"
    elif [ "$testname" == "randwrite" ];then
        iotype="randwrite"
    fi
    logfile=${logdir}/${testname}_${filesize}_${runtime}.log
    fio -filename=${testfile} -direct=1 -iodepth=100 -thread -rw=${iotype} -ioengine=psync -bs=8k -size=${filesize} -numjobs=${numjobs} -runtime=${runtime} -group_reporting -name=${testname}  > ${logfile} 2>&1	
}

function exe_fio_rw()
{
    testname=$1
    if [ "$testname" == "randrw30" ];then
        iotype="randrw"
        rwmixwrite=30
    elif [ "$testname" == "randrw70" ];then
        iotype="randrw"
        rwmixwrite=70
    fi
    logfile=${logdir}/${testname}_${filesize}_${runtime}.log
    fio -filename=${testfile} -direct=1 -iodepth=100 -thread -rw=${iotype} -rwmixwrite=${rwmixwrite} -ioengine=psync -bs=8k -size=${filesize} -numjobs=${numjobs} -runtime=${runtime} -group_reporting -name=${testname}  > ${logfile} 2>&1	
}

function exe_fio()
{
    for testname in ${testnames1[@]}
    do
        echo `date "+%Y-%m-%d %H:%M:%S"` "start to test $testname"
        exe_fio_r_w $testname
    done
    for testname in ${testnames2[@]}
    do
        echo `date "+%Y-%m-%d %H:%M:%S"` "start to test $testname"
        exe_fio_rw  $testname
    done
}


function check_param()
{
    if [ ! -d  "${datadir}" ];then
        echo "please input correct data dir!"
        echo "usage: sh $0 datadir runtime filesize"
        exit 1
    fi
    mkdir -p ${logdir}
    if [ "x$runtime" == "x" ];then
        echo "please input correct run time!"
        echo "usage: sh $0 datadir runtime filesize"
        exit 1
    fi
    if [ "$runtime" -gt 3600 ];then
        echo "the runtime is greater than 1 hours, if you want to use this param,please edit this scripts"
        exit 1
    fi
    if [ "x$filesize" == "x" ];then
        echo "the file size is  default 10G"
        filesize="10G"
        #sleep 2
    fi
    echo "runtime is ${runtime}s"
    echo "testfile is $testfile,size is $filesize"
    echo "logdir is $logdir"
}


datadir=$1
runtime=$2
filesize=$3
numjobs=20
testfile=${datadir}/fio_test.data
logdir=${datadir}/log
testnames1=(randread seq_read seq_write randwrite)
testnames2=(randrw30 randrw70)

check_param
exe_fio

```

脚本入参说明：
- 第一个参数：datadir，fio测试文件的目录
- 第二参数：runtime， 单个测试项的持续时长，单位：秒
- 第三个参数：filesize，测试文件的大小，默认为`10GB`


> 切记：
>
> 1. 理解脚本内容后，方可在现场环境执行。
> 2. 如果要执行fio命令的**file**参数为磁盘路径，谨记不要在**系统盘**、**有数据的磁盘**上直接测试。

脚本对如下场景进行测试：

- 随机读
- 顺序读
- 顺序写
- 随机写
- 读写混合，写占30%
- 读写混合，写占70%

测试结果示例如下：

| 测试项                                       | 指标 | adb01      |
| -------------------------------------------- | ---- | ---------- |
| 随机读                                       | bw   | 13409KB/s  |
|                                              | iops | 1676       |
| 顺序读                                       | bw   | 1108.2MB/s |
|                                              | iops | 141950     |
| 顺序写                                       | bw   | 145554KB/s |
|                                              | iops | 18194      |
| 随机写                                       | bw   | 14209KB/s  |
|                                              | iops | 1776       |
| 混合随机读写      （写占 30%）      上读下写 | bw   | 11491KB/s  |
|                                              | iops | 1436       |
|                                              | bw   | 4961.9KB/s |
|                                              | iops | 620        |
| 混合随机读写      （写占 70%）      上读下写 | bw   | 4641.8KB/s |
|                                              | iops | 580        |
|                                              | bw   | 10908KB/s  |
|                                              | iops | 1363       |



##### 参考链接：

- http://blog.yufeng.info/archives/2104
- https://my.oschina.net/u/2961972/blog/790503
- http://blog.itpub.net/26855487/viewspace-754346/
- http://blog.chinaunix.net/uid-8116903-id-3914246.html
- http://www.cnblogs.com/StarStor/p/3892338.html