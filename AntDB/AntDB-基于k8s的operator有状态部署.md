# AntDB 基于k8s的operator有状态部署
***
本文主要探讨AntDB基于k8s通过operator实现有状态部署的实施方案。
通过本文实现下述功能：
* AntDB 镜像制作
* AntDB 应用部署
* 验证过程中的问题分析处理

***

# 版本说明
|postgres-operator 服务端版本|4.2.1|https://github.com/CrunchyData/postgres-operator/tree/v4.2.1|
|:-----|:-------|:-------|
|postgres-operator 客户端版本(pgo)|4.2.1|https://github.com/CrunchyData/postgres-operator/releases/download/v4.2.1/postgres-operator.4.2.1.tar.gz|
|kubernetes 版本|1.13+||
|docker 版本|18.09.8||
|go 版本|1.13.7|https://dl.google.com/go/go1.13.7.linux-amd64.tar.gz|
|expenv 版本|1.2.0|https://github.com/blang/expenv，expenv已在pgo客户端版本集成，但不用单独安装，直接安装pgo即可|
|AntDB 版本|4.1devel 461fafc|单机版|
|pgaudit 版本|1.3.0|https://github.com/pgaudit/pgaudit/archive/1.3.0.zip|
|容器内os 版本|centos7||

# 需要准备的镜像

**AntDB相关镜像：**

* antdb-ha

antdb-ha替换crunchydata官方的crunchy-postgres-ha镜像。其他镜像，全部使用官方默认镜像即可。

# 制作dockerfile
## 1. 从官方crunchy-postgres-ha镜像获取 源dockerfile
```
-- 方式一：从官方的 IMAGE HISTORY 获取信息
https://hub.docker.com/layers/crunchydata/crunchy-postgres-ha/centos7-11.6-4.2.1/images/sha256-ab5a0b020394e61156c1142f05e00d11ca43fb46698123fd3c4b74165af18dcb?context=explore

**注：dockerfile中部分指令已被转义过**

-- 方式二：镜像下载到本地后，使用 docker history --no-trunc  命令展示

# docker history --no-trunc crunchydata/crunchy-postgres-ha:centos7-11.6-4.2.1
IMAGE                                                                     CREATED             CREATED BY                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      SIZE                COMMENT
sha256:f76ab5247544d5b3b93a4009ccd616aee1b094571bf975f2b55ba17716847dbe   6 weeks ago         /bin/sh -c #(nop) CMD ["/usr/local/bin/patroni"]                                                                                                                                                                                                                                                                                                                                                                                                                                                0B                  
<missing>                                                                 6 weeks ago         /bin/sh -c #(nop) USER 26                                                                                                                                                                                                                                                                                                                                                                                                                                                                       0B                  
<missing>                                                                 6 weeks ago         /bin/sh -c #(nop) ENTRYPOINT ["/opt/cpm/bin/bootstrap-postgres-ha.sh"]                                                                                                                                                                                                                                                                                                                                                                                                                          0B                  
<missing>                                                                 6 weeks ago         /bin/sh -c #(nop) VOLUME ["/pgdata", "/pgwal", "/pgconf", "/backrestrepo", "/sshd"]                                                                                                                                                                                                                                                                                                                                                                                                             0B                  
<missing>                                                                 6 weeks ago         |7 BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata /bin/sh -c mkdir /.ssh && chown 26:0 /.ssh && chmod g+rwx /.ssh                                                                                                                                                                                                                                                                                                              0B                  
<missing>                                                                 6 weeks ago         |7 BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata /bin/sh -c chmod g=u /etc/passwd  && chmod g=u /etc/group                                                                                                                                                                                                                                                                                                                    1.2kB               
<missing>                                                                 6 weeks ago         |7 BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata /bin/sh -c chmod +x /opt/cpm/bin/yq                                                                                                                                                                                                                                                                                                                                          5.27MB              
<missing>                                                                 6 weeks ago         /bin/sh -c #(nop) ADD yq /opt/cpm/bin                                                                                                                                                                                                                                                                                                                                                                                                                                                           5.27MB              
<missing>                                                                 6 weeks ago         /bin/sh -c #(nop) ADD tools/pgmonitor/exporter/postgres /opt/cpm/bin/modules/pgexporter                                                                                                                                                                                                                                                                                                                                                                                                         96.1kB              
<missing>                                                                 6 weeks ago         /bin/sh -c #(nop) ADD conf/postgres-ha /opt/cpm/conf                                                                                                                                                                                                                                                                                                                                                                                                                                            1.9kB               
<missing>                                                                 6 weeks ago         /bin/sh -c #(nop) ADD bin/common /opt/cpm/bin                                                                                                                                                                                                                                                                                                                                                                                                                                                   6.63kB              
<missing>                                                                 6 weeks ago         /bin/sh -c #(nop) ADD bin/postgres-ha /opt/cpm/bin                                                                                                                                                                                                                                                                                                                                                                                                                                              53.3kB              
<missing>                                                                 6 weeks ago         /bin/sh -c #(nop) EXPOSE 5432                                                                                                                                                                                                                                                                                                                                                                                                                                                                   0B                  
<missing>                                                                 6 weeks ago         |7 BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata /bin/sh -c chown -R postgres:postgres /opt/cpm /var/lib/pgsql  /pgdata /pgwal /pgconf /backrestrepo /crunchyadm &&   chmod -R g=u /opt/cpm /var/lib/pgsql  /pgdata /pgwal /pgconf /backrestrepo /crunchyadm                                                                                                                                                                  266B                
<missing>                                                                 6 weeks ago         |7 BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata /bin/sh -c mkdir -p /opt/cpm/bin /opt/cpm/conf /pgdata /pgwal /pgconf /backrestrepo /crunchyadm                                                                                                                                                                                                                                                                              0B                  
<missing>                                                                 6 weeks ago         /bin/sh -c #(nop) ENV PATH="${PGROOT}/bin:${PATH}"                                                                                                                                                                                                                                                                                                                                                                                                                                              0B                  
<missing>                                                                 6 weeks ago         |7 BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata /bin/sh -c useradd crunchyadm -g 0 -u 17                                                                                                                                                                                                                                                                                                                                     32.8kB              
<missing>                                                                 6 weeks ago         |7 BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata /bin/sh -c pip3 install --upgrade setuptools python-dateutil  && pip3 install patroni[kubernetes]=="${PATRONI_VER}"                                                                                                                                                                                                                                                          41.5MB              
<missing>                                                                 6 weeks ago         |7 BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata /bin/sh -c yum -y install  --enablerepo="pgdg${PG_MAJOR//.}"  --setopt=skip_missing_names_on_install=False  gcc  python3-devel  python3-pip  python3-psycopg2  && yum -y clean all --enablerepo="pgdg${PG_MAJOR//.}"                                                                                                                                                         124MB               
<missing>                                                                 6 weeks ago         /bin/sh -c #(nop) LABEL name="postgres-ha"  summary="PostgreSQL ${PG_FULL} (PGDG) with Patroni"  description="Used for the deployment and management of highly-available PostgreSQL clusters using Patroni."  io.k8s.description="Crunchy PostgreSQL optimized for high-availability (HA)"  io.k8s.display-name="Crunchy PostgreSQL - HA Optimized"  io.openshift.tags="postgresql,postgres,postgis,sql,nosql,database,ha,crunchy"                                                              0B                  
<missing>                                                                 6 weeks ago         /bin/sh -c #(nop) ARG PATRONI_VER                                                                                                                                                                                                                                                                                                                                                                                                                                                               0B                  
<missing>                                                                 6 weeks ago         |7 BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata /bin/sh -c yum -y install  --enablerepo="pgdg${PG_MAJOR//.}"  --setopt=skip_missing_names_on_install=False  openssh-clients  openssh-server  pgaudit${PGAUDIT_LBL}  pgbackrest-${BACKREST_VER}  postgresql${PG_MAJOR//.}-contrib  postgresql${PG_MAJOR//.}-server  postgresql${PG_MAJOR//.}-plpython  psmisc  rsync  && yum -y clean all --enablerepo="pgdg${PG_MAJOR//.}"   89.5MB              
<missing>                                                                 6 weeks ago         /bin/sh -c #(nop) ARG PGAUDIT_LBL                                                                                                                                                                                                                                                                                                                                                                                                                                                               0B                  
<missing>                                                                 6 weeks ago         /bin/sh -c #(nop) ARG BACKREST_VER                                                                                                                                                                                                                                                                                                                                                                                                                                                              0B                  
<missing>                                                                 6 weeks ago         /bin/sh -c #(nop) ENV PGROOT="/usr/pgsql-${PG_MAJOR}" PGVERSION="${PG_MAJOR}"                                                                                                                                                                                                                                                                                                                                                                                                                   0B                  
<missing>                                                                 6 weeks ago         /bin/sh -c #(nop) ARG PG_MAJOR                                                                                                                                                                                                                                                                                                                                                                                                                                                                  0B                  
<missing>                                                                 6 weeks ago         |6 BASEVER=4.2.1 PGDG_REPO_RPM=https://download.postgresql.org/pub/repos/yum/11/redhat/rhel-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm PG_FULL=11.6 PG_LBL=11 PG_MAJOR=11 PREFIX=crunchydata /bin/sh -c yum -y install ${PGDG_REPO_RPM}  && sed -i 's/enabled=1/enabled=0/' /etc/yum.repos.d/pgdg*.repo  && yum -y install   --enablerepo="pgdg${PG_LBL}"   --setopt=skip_missing_names_on_install=False   postgresql${PG_LBL}  && yum -y clean all --enablerepo="pgdg${PG_LBL}"               54.4MB              
<missing>                                                                 6 weeks ago         /bin/sh -c #(nop) LABEL postgresql.version.major="${PG_MAJOR}"  postgresql.version="${PG_FULL}"                                                                                                                                                                                                                                                                                                                                                                                                 0B                  
<missing>                                                                 6 weeks ago         /bin/sh -c #(nop) ARG PG_LBL                                                                                                                                                                                                                                                                                                                                                                                                                                                                    0B                  
<missing>                                                                 6 weeks ago         /bin/sh -c #(nop) ARG PGDG_REPO_RPM=https://download.postgresql.org/pub/repos/yum/${PG_MAJOR}/redhat/rhel-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm                                                                                                                                                                                                                                                                                                                                           0B                  
<missing>                                                                 6 weeks ago         /bin/sh -c #(nop) ARG PG_MAJOR                                                                                                                                                                                                                                                                                                                                                                                                                                                                  0B                  
<missing>                                                                 6 weeks ago         |1 RELVER=4.2.1 /bin/sh -c yum -y update  && yum -y install   --setopt=skip_missing_names_on_install=False   bind-utils   epel-release   gettext   hostname   procps-ng  && yum -y clean all                                                                                                                                                                                                                                                                                                    98.5MB              
<missing>                                                                 6 weeks ago         /bin/sh -c #(nop) ENV LANG en_US.utf-8                                                                                                                                                                                                                                                                                                                                                                                                                                                          0B                  
<missing>                                                                 6 weeks ago         /bin/sh -c #(nop) ENV LC_ALL en_US.utf-8                                                                                                                                                                                                                                                                                                                                                                                                                                                        0B                  
<missing>                                                                 6 weeks ago         /bin/sh -c #(nop) COPY licenses /licenses                                                                                                                                                                                                                                                                                                                                                                                                                                                       411kB               
<missing>                                                                 6 weeks ago         /bin/sh -c #(nop) LABEL vendor="Crunchy Data"  url="https://crunchydata.com"  release="${RELVER}"  org.opencontainers.image.vendor="Crunchy Data"  os.version="7.7"                                                                                                                                                                                                                                                                                                                             0B                  
<missing>                                                                 3 months ago        /bin/sh -c #(nop)  CMD ["/bin/bash"]                                                                                                                                                                                                                                                                                                                                                                                                                                                            0B                  
<missing>                                                                 3 months ago        /bin/sh -c #(nop)  LABEL org.label-schema.schema-version=1.0 org.label-schema.name=CentOS Base Image org.label-schema.vendor=CentOS org.label-schema.license=GPLv2 org.label-schema.build-date=20191001                                                                                                                                                                                                                                                                                         0B                  
<missing>                                                                 3 months ago        /bin/sh -c #(nop) ADD file:45a381049c52b5664e5e911dead277b25fadbae689c0bb35be3c42dff0f2dffe in /                                                                                                                                                                                                                                                                                                                                                                                                203MB

**注：docker history返回的信息中，部分指令已被转义过**


-- 方式三： 使用dive 工具
1. 安装dive

curl -OL https://github.com/wagoodman/dive/releases/download/v0.6.0/dive_0.6.0_linux_amd64.rpm 

rpm -i dive_0.6.0_linux_amd64.rpm

2. 使用dive解析

# dive crunchydata/crunchy-postgres-ha:centos7-11.6-4.2.1
Fetching image...
Parsing image...
  ├─ [layer:  1] 09c9be1bbf7a182 : [==============================>] 100 % (585/585)
  ├─ [layer:  2] 124bbd261cd08f0 : [==============================>] 100 % (5867/5867)
  ├─ [layer:  3] 1705b85a9aaa47f : [==============================>] 100 % (4/4)
  ├─ [layer:  4] 24190ab9072740e : [==============================>] 100 % (21/21)
  ├─ [layer:  5] 24c9832bf9a06ec : [==============================>] 100 % (20/20)
  ├─ [layer:  6] 4a892c5e23877a2 : [==============================>] 100 % (9/9)
  ├─ [layer:  7] 4b1ca51a644b6ed : [==============================>] 100 % (10740/10740)
  ├─ [layer:  8] 4f806b1e80443f3 : [==============================>] 100 % (16/16)
  ├─ [layer:  9] 59e4b2f2a8b95eb : [==============================>] 100 % (3/3)
  ├─ [layer: 10] 639dc63c65ed657 : [==============================>] 100 % (32/32)
  ├─ [layer: 11] 6b56493f28f48a7 : [==============================>] 100 % (4034/4034)
  ├─ [layer: 12] 749e2cd66674fc6 : [==============================>] 100 % (8/8)
  ├─ [layer: 13] 889e739bbc9a45d : [==============================>] 100 % (11/11)
  ├─ [layer: 14] c32ffa11224d924 : [==============================>] 100 % (1/1)
  ├─ [layer: 15] c43a8a3b12fdd52 : [==============================>] 100 % (4614/4614)
  ├─ [layer: 16] c6a24450b9882d4 : [==============================>] 100 % (4/4)
  ├─ [layer: 17] eeb51100d797499 : [==============================>] 100 % (3548/3548)
  ├─ [layer: 18] ef5809238f74a73 : [==============================>] 100 % (205/205)
  ╧
Analyzing image...
Building cache...
[● Layers]─────────────────────────────────────────────────────────────────── [Current Layer Contents]────────────────────────────────────────────────────
Cmp Image ID                     Size  Command                                Permission     UID:GID       Size  Filetree$<2>
  $<sha256:77b174a6a187b610e4  203 MB  #(nop) ADD file:45a381049c52b5664e5e91 -rw-r--r--         0:0      12 kB  ├── anaconda-post.log$<2>
  $<sha256:77b174a6a187b610e4  203 MB  #(nop) ADD file:45a381049c52b5664e5e91$<2>-r--rw-         0:0      12 kB  ├── anaconda-post.log$<2>
  $<sha256:d380dd8c4d3c77320b  411 kB  #(nop) COPY licenses /licenses$<2>upda -rwxrwxrwx         0:0        0 B  ├── bin → usr/bin    $<2>
  $<sha256:edd2a8e9def2c34f44   98 MB  |1 RELVER=4.2.1 /bin/sh -c yum -y upda$<2>xr-xr-x         0:0     1.9 MB  ├── dev          $<2>
  $<sha256:3cde431f61b21a3ca5   54 MB  |6 BASEVER=4.2.1 PGDG_REPO_RPM=https:/$<2>xr-xr-x         0:0     9.3$<2> │   etc$<2>       <2>
  $<sha256:656c60eb4cc6884f75   90 MB  |7 BACKREST_VER=2.20 BASEVER=4.2.1 PAT$<2>-------         0:0       14 B  │   ├── .pwd.lock><2>
  $<sha256:3e00aea33289a162ea  124 MB  |7 BACKREST_VER=2.20 BASEVER=4.2.1 PAT$<2>-r--r--         0:0       14 B  │   ├──$BUILDTIME$<2>
  $<sha256:37927ebbaccfbf0f1f   42 MB  |7 BACKREST_VER=2.20 BASEVER=4.2.1 PAT$<2>-r--r--         0:0     5.1 kB  │   ├── DIR_COLORS$<2>color
  $<sha256:dd64c27432ac9e8e54   33 kB  |7 BACKREST_VER=2.20 BASEVER=4.2.1 PAT$<2>-r--r--         0:0     5.7 kB  │   ├── DIR_COLORS.256color$<2>
  $<sha256:5969c4e29870d384f0     0 B  |7 BACKREST_VER=2.20 BASEVER=4.2.1 PAT$<2>-r--r--         0:0     4.7 kB  │   ├── DIR_COLORS.lightbgcolor$<2>
  $<sha256:e3d8be265d650cea12   266 B  |7 BACKREST_VER=2.20 BASEVER=4.2.1 PAT$<2>-r--r--         0:0       94 B  │   ├── GREP_COLORS        
  $<sha256:f9c1d6135c7aec4a6f   53 kB  #(nop) ADD bin/postgres-ha /opt/cpm/bi$<2>xr-xr-x         0:0     1232 B  │   ├── GeoIP.conf             
  $<sha256:dc49acfc16ee82f14e  6.6 kB  #(nop) ADD bin/common /opt/cpm/bin$<2> drwxr-xr-x         0:0      232 B  │   │   X11                    $<2>
  $<sha256:e7b5179c42677534c0  1.9 kB  #(nop) ADD conf/postgres-ha /opt/cpm/c$d2>xr-xr-x         0:0        0 B  │   │   ├── applnk $<2>
  $<sha256:6d2e28732983728809   96 kB  #(nop) ADD tools/pgmonitor/exporter/po$<2>xr-xr-x         0:0        0 B  │   │   ├── fontpath.d$<2>
  $<sha256:f1460a6313a6dd215b  5.3 MB  #(nop) ADD yq /opt/cpm/bin$<2>.2.1 PAT -rw-r--r--         0:0      232 B  │   │   └── xorg.conf.d$<2>.conf
  $<sha256:bbeb3ec67b9ff4782e  5.3 MB  |7 BACKREST_VER=2.20 BASEVER=4.2.1 PAT$-2>-r--r--         0:0      232 B  │   ├──    t└── 00-keyboard.conf$<2>
  $<sha256:68109fd49e345cc01e  1.2 kB  |7 BACKREST_VER=2.20 BASEVER=4.2.1 PAT$-2>-r--r--         0:0     1 16kB  │   ├── adjtime.rpmsave$<2>
  $<sha256:fcee5bafb4db806c41     0 B  FROM sha256:fcee5bafb4db806c41$<2>     -rw-r--r--         0:0     1.5 kB  │   ├── aliases                 
[Layer Details]──────────────────────────────────────────────────────────────$drwxr-xr-x         0:0        0 B  │   ├── alternatives$<2>        
                                                                              -rwxrwxrwx         0:0        0 B  │   │   ├── ld → /usr/bin/ld.bfd → /usr/lDigest: $<2>sha256:77b174a6a187b610e4699546bd973a8d1e77663796e3724318a2a4b24cb-rwxrwxrwx         0:0        0 B  │   │   ├── libnssckbi.so.x86_64 → /usr/l
a0             656c60eb4cc6884f75cbc95322b9b071fbe4940f5824a77ce88743712042a8$-rwxrwxrwx         0:0        0 B $<2> │   ├── pgsql-clusterdb → /usr/pgsql-aa$<2>2>$<2>                                                                  -rwxrwxrwx         0:0        0 B $<2> ├── ├$<2pgsql-clusterdbman → /usr/pgs
#(nop) ADD file:45a381049
c52b5664e5e911dead277b25fadbae689c0bb35be3c42dff0f2d -rwxrwxrwx         0:0        0 B $<2> │   ├── pgsql-createdb → /usr/pgsql-1q7-BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FUL$-rwxrwxrwx         0:0        0 B $<2> │   ├── pgsql-createdbman → /usr/pgsqL=11.6 PG_MAJOR=11 PREFIX=crunchydata /bin/sh -c yum -y install  --enablerepo$-rwxrwxrwx         0:0        0 B $<2> │   ├── pgsql-createuser → /usr/pgsql="pgdg${PG_MAJOR//.}"  --setopt=skip_missing_names_on_install=False  openssh-$-rwxrwxrwx         0:0        0 B $<2> │   ├── pgsql-createuserman → /usr/pgclients  openssh-server  pgaudit${PGAUDIT_LBL}  pgbackrest-${BACKREST_VER}  p<-rwxrwxrwx         0:0        0 B $<2> │   ├── pgsql-dropdb → /usr/pgsql-11/ostgresql${PG_MAJOR//.}-contrib  postgresql${PG_MAJOR//.}-server  postgresql$$-rwxrwxrwx         0:0        0 B $<2> │   ├── pgsql-dropdbman → /usr/pgsql-{PG_MAJOR//.}-plpython  psmisc$<rsync  && yum -y clean all --enablerepo="pgdg$-rwxrwxrwx         0:0        0 B $<2> │   ├── pgsql-dropuser → /usr/pgsql-1${PG_MAJOR//.}"  $      $<2>$<2>2>                                           $-rwxrwxrwx         0:0        0 B $<2><│  L├── pgsql-dropuserman → /usr/pgsq$<2>$<2>$<2>>^A$<2>$<2>  Show aggregated changes ▏                                                      $<2>


```

## 2. 制作自己的dockerfile文件antdb-ha.df 
从上述方式获取的被转义过的dockerfile中，制作自己的dockerfile

```
FROM docker.io/centos:7.7.1908
ARG RELVER="4.2.1"
ARG PG_FULL="11.6"
LABEL vendor="Crunchy Data" 	url="https://crunchydata.com" 	release="${RELVER}" 	org.opencontainers.image.vendor="Crunchy Data" 	os.version="7.7"
COPY licenses /licenses
ENV LC_ALL en_US.utf-8
ENV LANG en_US.utf-8
#|1 RELVER=4.2.1 /bin/sh -c yum -y update 	&& yum -y install 		--setopt=skip_missing_names_on_install=False 		bind-utils 		epel-release 		gettext 		hostname 		procps-ng 	&& yum -y clean all
RUN export RELVER=4.2.1 && yum -y update 	&& yum -y install 		--setopt=skip_missing_names_on_install=False 		bind-utils 		epel-release 		gettext 		hostname 		procps-ng 	&& yum -y clean all
ARG PG_MAJOR
ARG PGDG_REPO_RPM=https://download.postgresql.org/pub/repos/yum/${PG_MAJOR}/redhat/rhel-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
ARG PG_LBL
LABEL postgresql.version.major="${PG_MAJOR}" 	postgresql.version="${PG_FULL}"
#|6 BASEVER=4.2.1 PGDG_REPO_RPM=https://download.postgresql.org/pub/repos/yum/11/redhat/rhel-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm PG_FULL=11.6 PG_LBL=11 PG_MAJOR=11 PREFIX=crunchydata /bin/sh -c yum -y install ${PGDG_REPO_RPM} 	&& sed -i 's/enabled=1/enabled=0/' /etc/yum.repos.d/pgdg*.repo 	&& yum -y install 		--enablerepo="pgdg${PG_LBL}" 		--setopt=skip_missing_names_on_install=False 		postgresql${PG_LBL} 	&& yum -y clean all --enablerepo="pgdg${PG_LBL}"
RUN export BASEVER=4.2.1 PGDG_REPO_RPM=https://download.postgresql.org/pub/repos/yum/11/redhat/rhel-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm PG_FULL=11.6 PG_LBL=11 PG_MAJOR=11 PREFIX=crunchydata && yum -y install ${PGDG_REPO_RPM} 	&& sed -i 's/enabled=1/enabled=0/' /etc/yum.repos.d/pgdg*.repo 	&& yum -y install 		--enablerepo="pgdg${PG_LBL}" 		--setopt=skip_missing_names_on_install=False 		postgresql${PG_LBL} 	&& yum -y clean all --enablerepo="pgdg${PG_LBL}"
ARG PG_MAJOR
ENV PGROOT="/usr/pgsql-${PG_MAJOR}" PGVERSION="${PG_MAJOR}"
ARG BACKREST_VER
ARG PGAUDIT_LBL
#|7 BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata /bin/sh -c yum -y install 	--enablerepo="pgdg${PG_MAJOR//.}" 	--setopt=skip_missing_names_on_install=False 	openssh-clients 	openssh-server 	pgaudit${PGAUDIT_LBL} 	pgbackrest-${BACKREST_VER} 	postgresql${PG_MAJOR//.}-contrib 	postgresql${PG_MAJOR//.}-server 	postgresql${PG_MAJOR//.}-plpython 	psmisc 	rsync 	&& yum -y clean all --enablerepo="pgdg${PG_MAJOR//.}"
RUN export BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata && yum -y install 	--enablerepo="pgdg${PG_MAJOR//.}" 	--setopt=skip_missing_names_on_install=False 	openssh-clients 	openssh-server 	pgaudit${PGAUDIT_LBL} 	pgbackrest-${BACKREST_VER} 	postgresql${PG_MAJOR//.}-contrib 	postgresql${PG_MAJOR//.}-server 	postgresql${PG_MAJOR//.}-plpython 	psmisc 	rsync 	&& yum -y clean all --enablerepo="pgdg${PG_MAJOR//.}"
ARG PATRONI_VER
LABEL name="postgres-ha" 	summary="PostgreSQL ${PG_FULL} (PGDG) with Patroni" 	description="Used for the deployment and management of highly-available PostgreSQL clusters using Patroni." 	io.k8s.description="Crunchy PostgreSQL optimized for high-availability (HA)" 	io.k8s.display-name="Crunchy PostgreSQL - HA Optimized" 	io.openshift.tags="postgresql,postgres,postgis,sql,nosql,database,ha,crunchy"
#|7 BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata /bin/sh -c yum -y install 	--enablerepo="pgdg${PG_MAJOR//.}" 	--setopt=skip_missing_names_on_install=False 	gcc 	python3-devel 	python3-pip 	python3-psycopg2 	&& yum -y clean all --enablerepo="pgdg${PG_MAJOR//.}"
RUN export BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata && yum -y install 	--enablerepo="pgdg${PG_MAJOR//.}" 	--setopt=skip_missing_names_on_install=False 	gcc 	python3-devel 	python3-pip 	python3-psycopg2 	&& yum -y clean all --enablerepo="pgdg${PG_MAJOR//.}"
#|7 BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata /bin/sh -c pip3 install --upgrade setuptools python-dateutil  && pip3 install patroni[kubernetes]=="${PATRONI_VER}"
RUN export BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata && pip3 install --upgrade setuptools python-dateutil  && pip3 install patroni[kubernetes]=="${PATRONI_VER}"
#|7 BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata /bin/sh -c useradd crunchyadm -g 0 -u 17
RUN export BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata && useradd crunchyadm -g 0 -u 17
ENV PATH="${PGROOT}/bin:${PATH}"
#|7 BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata /bin/sh -c mkdir -p /opt/cpm/bin /opt/cpm/conf /pgdata /pgwal /pgconf /backrestrepo /crunchyadm
RUN export BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata && mkdir -p /opt/cpm/bin /opt/cpm/conf /pgdata /pgwal /pgconf /backrestrepo /crunchyadm
#|7 BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata /bin/sh -c chown -R postgres:postgres /opt/cpm /var/lib/pgsql 	/pgdata /pgwal /pgconf /backrestrepo /crunchyadm &&  	chmod -R g=u /opt/cpm /var/lib/pgsql 	/pgdata /pgwal /pgconf /backrestrepo /crunchyadm
RUN export BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata && chown -R postgres:postgres /opt/cpm /var/lib/pgsql 	/pgdata /pgwal /pgconf /backrestrepo /crunchyadm &&  	chmod -R g=u /opt/cpm /var/lib/pgsql 	/pgdata /pgwal /pgconf /backrestrepo /crunchyadm
EXPOSE 5432
ADD bin/postgres-ha  /opt/cpm/bin
ADD bin/common       /opt/cpm/bin
ADD conf/postgres-ha /opt/cpm/conf
ADD tools/pgmonitor/exporter/postgres /opt/cpm/bin/modules/pgexporter
ADD yq               /opt/cpm/bin
#|7 BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata /bin/sh -c chmod +x /opt/cpm/bin/yq
RUN export BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata && chmod +x /opt/cpm/bin/yq
#|7 BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata /bin/sh -c chmod g=u /etc/passwd  && chmod g=u /etc/group
RUN export BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata && chmod g=u /etc/passwd  && chmod g=u /etc/group
#|7 BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata /bin/sh -c mkdir /.ssh && chown 26:0 /.ssh && chmod g+rwx /.ssh
RUN export BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata && mkdir /.ssh && chown 26:0 /.ssh && chmod g+rwx /.ssh
COPY pkg/antdb41.tar.gz /tmp/
RUN cp -fr /usr/pgsql-11 /usr/pgsql-11-bak && rm -Rf /usr/pgsql-11/* && tar -xf antdb41.tar.gz -C /usr/pgsql-11 && chmod -R 755 /usr/pgsql-11
VOLUME ["/pgdata", "/pgwal", "/pgconf", "/backrestrepo", "/sshd"]
ENTRYPOINT ["/opt/cpm/bin/bootstrap-postgres-ha.sh"]
USER 26
CMD ["/usr/local/bin/patroni"]
```


**注：**

1. 官方镜像使用了  "|1 及 |2、|3 等" 特殊命令。该命令直接复制运行构建镜像，会报语法解析的错误。

通过分析该命令后，发现该命令将命令所需的变量和后续真正执行的操作绑定到了一条命令中，以减少镜像的level层数

|7 BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata /bin/sh -c pip3 install --upgrade setuptools python-dateutil  && pip3 install patroni[kubernetes]=="${PATRONI_VER}"

我们使用下述变通的方式替换即可

使用export命令将参数在该命令中生效，通过 && 紧接着执行正在的操作，即可。

RUN export BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata && pip3 install --upgrade setuptools python-dateutil  && pip3 install patroni[kubernetes]=="${PATRONI_VER}"

2. dockerfile中的FROM关键字被转义了，如何找到基础镜像？

从docker history的第二行命令中返回的信息如下，可以发现这是一个centos的官方基础镜像。

LABEL org.label-schema.schema-version=1.0 org.label-schema.name=CentOS Base Image org.label-schema.vendor=CentOS org.label-schema.license=GPLv2 org.label-schema.build-date=20191001

因此直接按下述改写即可。

FROM docker.io/centos:7.7.1908

3. dockerfile中ADD命令使用到的源文件，如何获取？

--方式一： 使用docker cp 命令(适合所有状态的容器)
```
# docker cp 54d4e6861aef:/opt/cpm/bin/common_lib.sh $HOME/xxx
```
--方式二： 登录容器后，sftp 连接到本机，使用put传输(只适合running状态的容器)
```
# put -r /opt/cpm/bin
```
4. dockerfile中ARG参数，该参数用于构建镜像阶段参数传递，此类镜像如何构建？

build时通过--build-arg选项赋值传递，多个ARG使用多个选项赋值

docker build --build-arg PG_MAJOR=11 --build-arg PG_LBL=11 --build-arg BACKREST_VER=2.20 --build-arg PGAUDIT_LBL=13_11 --build-arg PATRONI_VER=1.6.3 -t antdb-ha -f antdb-ha.df .


# 构建AntDB镜像

## 1. 构建镜像
```
docker build --build-arg PG_MAJOR=11 --build-arg PG_LBL=11 --build-arg BACKREST_VER=2.20 --build-arg PGAUDIT_LBL=13_11 --build-arg PATRONI_VER=1.6.3 -t antdb-ha -f antdb-ha.df .
```

## 2. 给镜像打标签

-- 1. 为什么要打标签

构建后的镜像，如下。该镜像名，没有前缀，即从哪个镜像仓库拉取下载的。

```
# docker images|more
REPOSITORY                                                       TAG                  IMAGE ID            CREATED             SIZE
antdb-ha                                                         latest               0c3a5a666929        4 minutes ago       723MB
```

该前缀默认crunchydata，即从该仓库拉取，对应配置文件为

```
# cat $PGOROOT/conf/postgres-operator/pgo.yaml|grep CCPImagePrefix:
  CCPImagePrefix:  crunchydata
```

此处，因为其他镜像仍使用官方的默认镜像，因此我们不做调整，只将antdb-ha的镜像打个tag，推入本地即可(docker pull时优先从本地拉取)。

-- 2. 打标签

```
# docker tag  antdb-ha:latest crunchydata/antdb-ha:latest
```

验证

```
# docker images|grep antdb-ha
crunchydata/antdb-ha                                             latest               0c3a5a666929        12 minutes ago      723MB
antdb-ha                                                         latest               0c3a5a666929        12 minutes ago      723MB
```

## 3. 将镜像推送至k8s集群的其他主机
若不推送至其他主机，当pod在其他主机启动时，会报 镜像拉取失败 的错误。

有如下两种方式：

1. 推入本地的镜像仓库，其他主机再从本地仓库拉取

2. 使用docker save将镜像保存为本地tar文件，ftp至其他主机后，使用docker load装载

此处，我们使用方式 2。镜像较大，save阶段需耐心等待几分钟。

```
-- 1. 镜像打包并传输至其他主机
# docker save crunchydata/antdb-ha:latest -o /data/antdb-ha.tar.gz
# scp /data/antdb-ha.tar.gz root@10.x.x.x:/data
root@10.x.x.x's password: 
antdb-ha.tar.gz                                                                                                         100%  713MB  78.2MB/s   00:09

-- 2. 其他主机装载镜像
# docker load  -i /data/antdb-ha.tar.gz
c621b9e31f8b: Loading layer [==================================================>]  542.7kB/542.7kB
6247beb2ee41: Loading layer [==================================================>]  104.3MB/104.3MB
884537517591: Loading layer [==================================================>]  55.44MB/55.44MB
80bd442d847d: Loading layer [==================================================>]  93.72MB/93.72MB
1503171e2cc6: Loading layer [==================================================>]  129.5MB/129.5MB
91fe7e6a1f35: Loading layer [==================================================>]  44.55MB/44.55MB
c885caf3adaf: Loading layer [==================================================>]  44.03kB/44.03kB
94779360ef3e: Loading layer [==================================================>]  5.632kB/5.632kB
8a86fba7c2e5: Loading layer [==================================================>]  9.728kB/9.728kB
02e5db3d3db7: Loading layer [==================================================>]  15.36kB/15.36kB
057e5ff9101a: Loading layer [==================================================>]  67.58kB/67.58kB
c56704fde375: Loading layer [==================================================>]  11.26kB/11.26kB
037f62bf44b4: Loading layer [==================================================>]  121.3kB/121.3kB
3186756f2835: Loading layer [==================================================>]  5.272MB/5.272MB
d5d7315dedd0: Loading layer [==================================================>]  5.272MB/5.272MB
c3e74a25a0a2: Loading layer [==================================================>]  4.096kB/4.096kB
1070a9d07b39: Loading layer [==================================================>]  1.536kB/1.536kB
89784c745e3d: Loading layer [==================================================>]  20.18MB/20.18MB
5c0682f87deb: Loading layer [==================================================>]  76.94MB/76.94MB
Loaded image: crunchydata/antdb-ha:latest

-- 3. 检查镜像装载是否成功
# docker images|grep antdb-ha
crunchydata/antdb-ha                                                       latest               0c3a5a666929        24 minutes ago      723MB
```

# 创建AntDB 应用

```
# pgo create cluster antdb --ccp-image=antdb-ha --ccp-image-tag=latest --namespace=pgouser1
created Pgcluster antdb 
workflow id b67b1140-0393-471b-8bb6-52716c4c31c0
```

验证 antdb 应用部署是否成功
```
# kubectl get pod -n pgouser1
NAME                                             READY   STATUS             RESTARTS   AGE
antdb-74677dd9c4-7gjq7                           1/1     Running            0          11m
antdb-backrest-shared-repo-7b87556cb6-prvm2      1/1     Running            0          11m
antdb-stanza-create-vnkvl                        0/1     Completed          0          11m
backrest-backup-antdb-g9z44                      0/1     Completed          0          10m
```

# 访问AntDB服务
## 获取AntDB 的服务信息

```
# kubectl -n pgouser1 describe pod antdb-74677dd9c4-7gjq7|grep conn_url
{"conn_url":"postgres://172.30.53.29:5432/postgres","api_url":"http://172.30.53.29:8009/patroni","state":"running","role":"master","versio...
```
从返回的信息，可以获取服务地址为 172.30.53.29:5432/postgres

由于该镜像默认将ip使用md5访问，且数据库的初始用户密码未提供。因此 需要通过docker exec 方式进入容器后，通过localhost方式登录后，修改密码后，方能连接。步骤如下：

1. 该容器的启动脚本为 /opt/cpm/bin/bootstrap-postgres-ha.sh，因此搜索该启动脚本
```
# docker ps|grep bootst
de02a34bc7dd        f76ab5247544                       "/opt/cpm/bin/bootst…"   About an hour ago   Up About an hour                               k8s_database_mycluster-9b6b9799b-tqq8p_pgouser1_ea171fb9-0623-4e76-a6d5-28d2a72eeb9d_0
```

容器id 为 第一列信息 ：de02a34bc7dd

2. 进入该容器
```
# docker exec -it de02a34bc7dd /bin/bash
```

3. 登录数据库，查看数据库版本信息及调整用户密码
```
bash-4.2$ psql -p 5432
psql (11.6)
Type "help" for help.

postgres=# select version(); 
                                                           version                                                            
------------------------------------------------------------------------------------------------------------------------------
 PostgreSQL 11.5 ADB 4.1devel 461fafc on x86_64-pc-linux-gnu, compiled by gcc (GCC) 4.8.5 20150623 (Red Hat 4.8.5-36), 64-bit
(1 row)

postgres=# alter user testuser password 'xxxxxx';
ALTER ROLE

postgres=# \l+
                                                                    List of databases
   Name    |  Owner   | Encoding |   Collate   |    Ctype    |   Access privileges   |  Size   | Tablespace |                Description                 
-----------+----------+----------+-------------+-------------+-----------------------+---------+------------+--------------------------------------------
 postgres  | postgres | UTF8     | en_US.utf-8 | en_US.utf-8 |                       | 7709 kB | pg_default | default administrative connection database
 template0 | postgres | UTF8     | en_US.utf-8 | en_US.utf-8 | =c/postgres          +| 7537 kB | pg_default | unmodifiable empty database
           |          |          |             |             | postgres=CTc/postgres |         |            | 
 template1 | postgres | UTF8     | en_US.utf-8 | en_US.utf-8 | =c/postgres          +| 7537 kB | pg_default | default template for new databases
           |          |          |             |             | postgres=CTc/postgres |         |            | 
 userdb    | postgres | UTF8     | en_US.utf-8 | en_US.utf-8 | =Tc/postgres         +| 7709 kB | pg_default | 
           |          |          |             |             | postgres=CTc/postgres+|         |            | 
           |          |          |             |             | testuser=CTc/postgres |         |            | 
(4 rows)

postgres=# \du
                                    List of roles
  Role name  |                         Attributes                         | Member of 
-------------+------------------------------------------------------------+-----------
 crunchyadm  |                                                            | {}
 postgres    | Superuser, Create role, Create DB, Replication, Bypass RLS | {}
 primaryuser | Replication                                                | {}
 testuser    |                                                            | {}

```

4. 修改密码后，可使用 虚拟ip访问了
退出该容器，使用psql连接虚拟ip访问

```
# psql -h 172.30.53.29 -p 5432 -d userdb -U testuser
Password for user testuser: 
psql (11.5, server 11.6)
Type "help" for help.

userdb=> 
```

5. 也可以使用k8s的CLUSTER-IP 访问
```
--获取CLUSTER-IP的地址
# kubectl get service -n pgouser1
NAME                           TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                                         AGE
antdb                        ClusterIP   10.254.230.242   <none>        5432/TCP,10000/TCP,2022/TCP,9187/TCP,8009/TCP   74m
antdb-backrest-shared-repo   ClusterIP   10.254.122.152   <none>        2022/TCP                                        74m

--通过CLUSTER-IP访问AntDB服务
# psql -h 10.254.230.242 -p 5432 -d userdb -U testuser
Password for user testuser: 
psql (11.5, server 11.6)
Type "help" for help.

userdb=> 
```

# 遇到的问题
## 1. FATAL:  could not access file "pgaudit.so": No such file or directory

**问题现象**
```
# docker logs 167c86bbd6e2
2020-02-28 05:51:59,770 INFO: trying to bootstrap a new cluster
The files belonging to this database system will be owned by user "postgres".
This user must also own the server process.

The database cluster will be initialized with locale "en_US.utf-8".
The default text search configuration will be set to "english".

Data page checksums are disabled.

fixing permissions on existing directory /pgdata/antdb1 ... ok
creating subdirectories ... ok
selecting default max_connections ... 100
selecting default shared_buffers ... 128MB
selecting default timezone ... UTC
selecting dynamic shared memory implementation ... posix
creating configuration files ... ok
running bootstrap script ... ok
performing post-bootstrap initialization ... ok
syncing data to disk ... ok

Success. You can now start the database server using:

    /usr/pgsql-11/bin/pg_ctl -D /pgdata/antdb1 -l logfile start


WARNING: enabling "trust" authentication for local connections
You can change this by editing pg_hba.conf or using the option -A, or
--auth-local and --auth-host, the next time you run initdb.
2020-02-28 05:52:03,084 INFO: postmaster pid=204
2020-02-28 05:52:03.096 UTC [204] FATAL:  could not access file "pgaudit.so": No such file or directory
2020-02-28 05:52:03.096 UTC [204] LOG:  database system is shut down
/tmp:5432 - no response
2020-02-28 05:52:04,105 ERROR: postmaster is not running
2020-02-28 05:52:04,107 INFO: removing initialize key after failed attempt to bootstrap the cluster
```

**错误原因** 官方的镜像使用了pgaudit插件，需要安装到我们的antdb-ha镜像里面

**解决方式** 

调整dockerfile，将pgaudit编译进AntDB的程序中 或 直接提供已编译过pgaudit的AntDB的tar包，直接使用 ADD 命令加入dockerfile即可。 

# 总结
AntDB 单机版镜像已部署成功，后续在使用/ha切换/operator和其他一些方面，仍需测试验证。

另外，一些专用术语(如镜像前缀crunchydata如何调整等)、数据库参数调整、配套工具等，仍需进一步研究，使其更接近于AntDB的品性。

# 参考
AntDB QQ群号：496464280

[AntDB github链接](https://github.com/ADBSQL)