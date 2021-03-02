## rhel,centos系列离线安装包准备

### 下载并安装 zfs-release 包
在zfsonlinux网站https://github.com/zfsonlinux/zfs/wiki/RHEL-and-CentOS 下载对应操作系统版本的zfs-release 包，网站只提供7.3-8.0 对应的版本，el7.2，el7.1 从这个链接下载http://download.zfsonlinux.org/epel/zfs-release.el7.noarch.rpm。

修改 /etc/yum.repos.d/zfs.repo , 将kmod 模式改为默认模式
```
[zfs] 模块enabled=1 改成enabled=0
[zfs-kmod] 模块enabled=0 改成enabled=1
```
### 离线下载zfs 和所需依赖的 rpm安装包
`yumdownloader zfs --resolve`
 
下载zfs 安装包和所需的依赖到当前文件夹

 centos7.1-7.7已下载的rpm包在10.21.20.175:/data/tools/zfs
 路径下,可以直接使用
### 安装zfs

将包含的安装文件的文件夹上传到目标服务器
```
rpm -ivh *.rpm  安装zfs 
 modprobe zfs   手动加载zfs模块到内核
 lsmod|grep zfs  检查一下zfs模块是否装载到内核，有类似的输出表示已安装成功

zfs                  3564425  0 
zunicode              331170  1 zfs
zavl                   15236  1 zfs
icp                   270148  1 zfs
zcommon                73440  1 zfs
znvpair                89131  2 zfs,zcommon
spl                   102412  4 icp,zfs,zcommon,znvpair
```

### 解决zfs加载不成功
`modprobe zfs 时报错 modprobe: FATAL: Module zfs not found`

该错误一般为安装的zfs 与当前操作系统内核不兼容。

可以尝试安装不同低版本的zfs安装包尝试与当前操作系统内核兼容

```
yum list --showduplicates|grep zfs
 查看有哪些低版本的安装包
zfs.x86_64                              0.7.12-1.el7_6                 zfs-kmod 
zfs.x86_64                              0.7.13-1.el7_6                 zfs-kmod
```
下载特定的版本zfs 包
`yumdownloader zfs-0.7.12  --resolve`

或者通过url在网站直接下载与操作系统对应的低版本的安装包(操作系统安装server模式的话需要8个rpm包，下面的url为一个示例)
```
http://download.zfsonlinux.org/epel/7.6/kmod/x86_64/zfs-0.7.12-1.el7_6.x86_64.rpm
http://download.zfsonlinux.org/epel/7.6/kmod/x86_64/spl-0.7.12-1.el7_6.x86_64.rpm
http://download.zfsonlinux.org/epel/7.6/kmod/x86_64/kmod-spl-0.7.12-1.el7_6.x86_64.rpm
http://download.zfsonlinux.org/epel/7.6/kmod/x86_64/kmod-zfs-0.7.12-1.el7_6.x86_64.rpm
http://download.zfsonlinux.org/epel/7.6/kmod/x86_64/libnvpair1-0.7.12-1.el7_6.x86_64.rpm
http://download.zfsonlinux.org/epel/7.6/kmod/x86_64/libuutil1-0.7.12-1.el7_6.x86_64.rpm
http://download.zfsonlinux.org/epel/7.6/kmod/x86_64/libzfs2-0.7.12-1.el7_6.x86_64.rpm
http://download.zfsonlinux.org/epel/7.6/kmod/x86_64/libzpool2-0.7.12-1.el7_6.x86_64.rpm
```



