
## 下载地址
https://github.com/openzfs/zfs/releases/tag/zfs-0.8.0

## 预处理
### 上传及解压
上传zfs源码文件：/opt/zfs-0.8.0.tar.gz
cd /opt
tar zxf zfs-0.8.0.tar.gz

### 安装依赖包
yum install -y libuuid-devel

yum install -y libblkid-devel

yum install -y kernel-devel

yum install -y libattr-devel

yum install -y zlib-devel

yum install -y libssl-devel

yum install -y openssl-devel

yum reinstall -y gcc

## 开始安装
### 编译

```shell
cd /opt/zfs-0.8.0
./configure
... ...
config.status: creating rpm/Makefile
config.status: creating rpm/redhat/Makefile
config.status: creating rpm/redhat/zfs.spec
config.status: creating rpm/redhat/zfs-kmod.spec
config.status: creating rpm/redhat/zfs-dkms.spec
config.status: creating rpm/generic/Makefile
config.status: creating rpm/generic/zfs.spec
config.status: creating rpm/generic/zfs-kmod.spec
config.status: creating rpm/generic/zfs-dkms.spec
config.status: creating zfs.release
config.status: creating zfs_config.h
config.status: executing depfiles commands
config.status: executing libtool commands
config.status: executing po-directories commands
[root@localhost zfs-0.8.0]# 
```

### make&make install

```shell
make
... ...
make[3]: Leaving directory `/usr/src/kernels/3.10.0-1127.el7.x86_64'
make[2]: Leaving directory `/opt/zfs-0.8.0/module'
make[2]: Entering directory `/opt/zfs-0.8.0'
./scripts/zfs-tests.sh -c
make[2]: Leaving directory `/opt/zfs-0.8.0'
make[1]: Leaving directory `/opt/zfs-0.8.0'
[root@localhost zfs-0.8.0]# 
```

```shell
[root@localhost zfs-0.8.0]# make install
make[4]: Leaving directory `/opt/zfs-0.8.0'
make[3]: Leaving directory `/opt/zfs-0.8.0'
make[2]: Leaving directory `/opt/zfs-0.8.0'
make[1]: Leaving directory `/opt/zfs-0.8.0'
[root@localhost zfs-0.8.0]# 
```

### 加载及启动项
#### 启动脚本
```shell
[root@localhost zfs-0.8.0]# vi /opt/zfs-0.8.0/zfs-start.sh
insmod /opt/zfs-0.8.0/module/spl/spl.ko
insmod /opt/zfs-0.8.0/module/avl/zavl.ko
insmod /opt/zfs-0.8.0/module/nvpair/znvpair.ko
insmod /opt/zfs-0.8.0/module/unicode/zunicode.ko
insmod /opt/zfs-0.8.0/module/zcommon/zcommon.ko
insmod /opt/zfs-0.8.0/module/lua/zlua.ko
insmod /opt/zfs-0.8.0/module/icp/icp.ko
insmod /opt/zfs-0.8.0/module/zfs/zfs.ko

systemctl start zfs-import-cache.service
systemctl start zfs-import-scan.service
systemctl start zfs-mount.service
systemctl start zfs-share.service
systemctl start zfs.target
systemctl start zfs-zed.service
```

```shell
[root@localhost zfs-0.8.0]#  chmod 700 /opt/zfs-0.8.0/zfs-start.sh
```

#### 启动服务
```shell
vi /usr/lib/systemd/system/load-zfs.service
[Unit]
Description=Load ZFS
Documentation=man:zfs(8)
DefaultDependencies=no

[Service]
RemainAfterExit=yes
ExecStart=/opt/zfs-0.8.0/zfs-start.sh

[Install]
WantedBy=multi-user.target
```

```shell
systemctl enable load-zfs.service
systemctl start load-zfs.service
```

### 验证
```shell
[root@localhost zfs-0.8.0]# zfs version
zfs-0.8.0-1
zfs-kmod-0.8.0-1
```

## 挂载磁盘

### 示例中使用sdb、sdc、sdd做挂载操作
```shell
[root@localhost zfs-0.8.0]# fdisk -l

Disk /dev/sda: 21.5 GB, 21474836480 bytes, 41943040 sectors
Units = sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disk label type: dos
Disk identifier: 0x000f2d4f

   Device Boot      Start         End      Blocks   Id  System
/dev/sda1   *        2048     2099199     1048576   83  Linux
/dev/sda2         2099200    41943039    19921920   8e  Linux LVM

Disk /dev/sdb: 1073 MB, 1073741824 bytes, 2097152 sectors
Units = sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes


Disk /dev/sdc: 1073 MB, 1073741824 bytes, 2097152 sectors
Units = sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes


Disk /dev/sdd: 1073 MB, 1073741824 bytes, 2097152 sectors
Units = sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes


Disk /dev/mapper/centos-root: 18.2 GB, 18249416704 bytes, 35643392 sectors
Units = sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes


Disk /dev/mapper/centos-swap: 2147 MB, 2147483648 bytes, 4194304 sectors
Units = sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes

[root@localhost zfs-0.8.0]# 
```
### 开始挂载
```shell
mkdir -p /data
zpool create -m /data data raidz /dev/sdb /dev/sdc /dev/sdd
zfs set compression=lz4 data
zfs set recordsize=64k data
zfs set recordsize=32k data
zfs set atime=off data
```

### 查看生成的zfs文件系统
```shell
[root@localhost zfs-0.8.0]# zpool status
  pool: data
 state: ONLINE
  scan: none requested
config:

	NAME        STATE     READ WRITE CKSUM
	data        ONLINE       0     0     0
	  raidz1-0  ONLINE       0     0     0
	    sdb     ONLINE       0     0     0
	    sdc     ONLINE       0     0     0
	    sdd     ONLINE       0     0     0

errors: No known data errors
```
至此安装完成。

## 备注
### 常用操作
```shell
zfs --help
usage: zfs command args ...
where 'command' is one of the following:

	version

	create [-p] [-o property=value] ... <filesystem>
	create [-ps] [-b blocksize] [-o property=value] ... -V <size> <volume>
	destroy [-fnpRrv] <filesystem|volume>
	destroy [-dnpRrv] <filesystem|volume>@<snap>[%<snap>][,...]
	destroy <filesystem|volume>#<bookmark>

	snapshot [-r] [-o property=value] ... <filesystem|volume>@<snap> ...
	rollback [-rRf] <snapshot>
	clone [-p] [-o property=value] ... <snapshot> <filesystem|volume>
	promote <clone-filesystem>
	rename [-f] <filesystem|volume|snapshot> <filesystem|volume|snapshot>
	rename [-f] -p <filesystem|volume> <filesystem|volume>
	rename -r <snapshot> <snapshot>
	bookmark <snapshot> <bookmark>
	program [-jn] [-t <instruction limit>] [-m <memory limit (b)>]
	    <pool> <program file> [lua args...]

	list [-Hp] [-r|-d max] [-o property[,...]] [-s property]...
	    [-S property]... [-t type[,...]] [filesystem|volume|snapshot] ...

	set <property=value> ... <filesystem|volume|snapshot> ...
	get [-rHp] [-d max] [-o "all" | field[,...]]
	    [-t type[,...]] [-s source[,...]]
	    <"all" | property[,...]> [filesystem|volume|snapshot|bookmark] ...
	inherit [-rS] <property> <filesystem|volume|snapshot> ...
	upgrade [-v]
	upgrade [-r] [-V version] <-a | filesystem ...>

	userspace [-Hinp] [-o field[,...]] [-s field] ...
	    [-S field] ... [-t type[,...]] <filesystem|snapshot>
	groupspace [-Hinp] [-o field[,...]] [-s field] ...
	    [-S field] ... [-t type[,...]] <filesystem|snapshot>
	projectspace [-Hp] [-o field[,...]] [-s field] ... 
	    [-S field] ... <filesystem|snapshot>

	project [-d|-r] <directory|file ...>
	project -c [-0] [-d|-r] [-p id] <directory|file ...>
	project -C [-k] [-r] <directory ...>
	project [-p id] [-r] [-s] <directory ...>

	mount
	mount [-lvO] [-o opts] <-a | filesystem>
	unmount [-f] <-a | filesystem|mountpoint>
	share [-l] <-a [nfs|smb] | filesystem>
	unshare <-a [nfs|smb] | filesystem|mountpoint>

	send [-DnPpRvLecwhb] [-[i|I] snapshot] <snapshot>
	send [-nvPLecw] [-i snapshot|bookmark] <filesystem|volume|snapshot>
	send [-nvPe] -t <receive_resume_token>
	receive [-vnsFhu] [-o <property>=<value>] ... [-x <property>] ...
	    <filesystem|volume|snapshot>
	receive [-vnsFhu] [-o <property>=<value>] ... [-x <property>] ... 
	    [-d | -e] <filesystem>
	receive -A <filesystem|volume>

	allow <filesystem|volume>
	allow [-ldug] <"everyone"|user|group>[,...] <perm|@setname>[,...]
	    <filesystem|volume>
	allow [-ld] -e <perm|@setname>[,...] <filesystem|volume>
	allow -c <perm|@setname>[,...] <filesystem|volume>
	allow -s @setname <perm|@setname>[,...] <filesystem|volume>

	unallow [-rldug] <"everyone"|user|group>[,...]
	    [<perm|@setname>[,...]] <filesystem|volume>
	unallow [-rld] -e [<perm|@setname>[,...]] <filesystem|volume>
	unallow [-r] -c [<perm|@setname>[,...]] <filesystem|volume>
	unallow [-r] -s @setname [<perm|@setname>[,...]] <filesystem|volume>

	hold [-r] <tag> <snapshot> ...
	holds [-rH] <snapshot> ...
	release [-r] <tag> <snapshot> ...
	diff [-FHt] <snapshot> [snapshot|filesystem]

	load-key [-rn] [-L <keylocation>] <-a | filesystem|volume>
	unload-key [-r] <-a | filesystem|volume>
	change-key [-l] [-o keyformat=<value>]
	    [-o keylocation=<value>] [-o pbkfd2iters=<value>]
	    <filesystem|volume>
	change-key -i [-l] <filesystem|volume>

Each dataset is of the form: pool/[dataset/]*dataset[@name]

For the property list, run: zfs set|get

For the delegated permission list, run: zfs allow|unallow
```

```shell
zpool --help
usage: zpool command args ...
where 'command' is one of the following:

	version

	create [-fnd] [-o property=value] ... 
	    [-O file-system-property=value] ... 
	    [-m mountpoint] [-R root] <pool> <vdev> ...
	destroy [-f] <pool>

	add [-fgLnP] [-o property=value] <pool> <vdev> ...
	remove [-nps] <pool> <device> ...

	labelclear [-f] <vdev>

	checkpoint [--discard] <pool> ...

	list [-gHLpPv] [-o property[,...]] [-T d|u] [pool] ... 
	    [interval [count]]
	iostat [[[-c [script1,script2,...][-lq]]|[-rw]] [-T d | u] [-ghHLpPvy]
	    [[pool ...]|[pool vdev ...]|[vdev ...]] [[-n] interval [count]]
	status [-c [script1,script2,...]] [-igLpPsvxD]  [-T d|u] [pool] ... 
	    [interval [count]]

	online [-e] <pool> <device> ...
	offline [-f] [-t] <pool> <device> ...
	clear [-nF] <pool> [device]
	reopen [-n] <pool>

	attach [-f] [-o property=value] <pool> <device> <new-device>
	detach <pool> <device>
	replace [-f] [-o property=value] <pool> <device> [new-device]
	split [-gLnPl] [-R altroot] [-o mntopts]
	    [-o property=value] <pool> <newpool> [<device> ...]

	initialize [-c | -s] <pool> [<device> ...]
	resilver <pool> ...
	scrub [-s | -p] <pool> ...
	trim [-dp] [-r <rate>] [-c | -s] <pool> [<device> ...]

	import [-d dir] [-D]
	import [-o mntopts] [-o property=value] ... 
	    [-d dir | -c cachefile] [-D] [-l] [-f] [-m] [-N] [-R root] [-F [-n]] -a
	import [-o mntopts] [-o property=value] ... 
	    [-d dir | -c cachefile] [-D] [-l] [-f] [-m] [-N] [-R root] [-F [-n]]
	    [--rewind-to-checkpoint] <pool | id> [newpool]
	export [-af] <pool> ...
	upgrade
	upgrade -v
	upgrade [-V version] <-a | pool ...>
	reguid <pool>

	history [-il] [<pool>] ...
	events [-vHf [pool] | -c]

	get [-Hp] [-o "all" | field[,...]] <"all" | property[,...]> <pool> ...
	set <property=value> <pool> 
	sync [pool] ...
```
### 常见报错
问题一：unable to build an empty module
方法：环境中gcc有问题，重装gcc。

问题二：you must rebuild you kernel without ...
原因：主机默认的kernel为debug模式
方法：指定不带debug的kernel路径：./configure --with-linux=/usr/src/kernels/3.10.0-1062.el7.bclinux.x86_64

问题三：FATAL: Module zfs not found
原因：服务load-zfs.service没启动。
方法：systemctl start load-zfs.service

问题四：missing, libssl-devel package required
原因：在centos下缺少openssl-devel
方法：yum install -y openssl-devel