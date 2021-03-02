# AntDB集群版 基于k8s的operator有状态部署
***
本文主要探讨AntDB集群版 基于k8s通过operator实现有状态部署的实施方案。
通过本文实现下述功能：
* gtm_coord组件的   antdb.cluster.gc-ha 镜像制作
* coordinator组件的 antdb.cluster.cn-ha 镜像制作
* datanode组件的    antdb.cluster.db-ha 镜像制作
* AntDB 集群应用部署
* 遗留问题说明

***

# 版本说明
|postgres-operator 服务端版本|4.2.1|https://github.com/CrunchyData/postgres-operator/tree/v4.2.1|
|:-----|:-------|:-------|
|postgres-operator 客户端版本(pgo)|4.2.1|https://github.com/CrunchyData/postgres-operator/releases/download/v4.2.1/postgres-operator.4.2.1.tar.gz|
|kubernetes 版本|1.13+||
|docker 版本|18.09.8||
|go 版本|1.13.7|https://dl.google.com/go/go1.13.7.linux-amd64.tar.gz|
|expenv 版本|1.2.0|https://github.com/blang/expenv，expenv已在pgo客户端版本集成，但不用单独安装，直接安装pgo即可|
|AntDB 版本|5.0devel a8a0374|集群版/分布式版|
|pgaudit 版本|1.3.0|https://github.com/pgaudit/pgaudit/archive/1.3.0.zip|
|容器内os 版本|centos7||

# 需要准备的镜像

**AntDB相关镜像：**

* antdb.cluster.gc-ha
* antdb.cluster.cn-ha
* antdb.cluster.db-ha

antdb.cluster.XX-ha替换crunchydata官方的crunchy-postgres-ha镜像。其他镜像，全部使用官方默认镜像即可。

# 制作dockerfile
## 1.1 gtm_coord节点的antdb.cluster.gc-ha的dockerfile 
**与AntDB单机版的dockerfile改动点说明：**
* 由于加入了PGXC的结构，因此容器的数据库初始化initdb，需要对应新增 --nodename xxx的初始化参数。通过调整容器的启动脚本，在patroni的配置文件中加入- nodename: ${PATRONI_NAME}实现，其中${PATRONI_NAME}为patroni软件的全局环境变量，取值为启动后POD的主机名。
* 由于加入了PGXC的结构，因此容器的原启动方式patroni，需要对应新增 --gtm_coord 的默认启动参数。通过修改patroni代码实现。

```
FROM docker.io/centos:7.7.1908
ARG RELVER="4.2.1"
ARG PG_FULL="11.6"
LABEL vendor="Crunchy Data"     url="https://crunchydata.com"   release="${RELVER}"     org.opencontainers.image.vendor="Crunchy Data"  os.version="7.7"
COPY licenses /licenses
ENV LC_ALL en_US.utf-8
ENV LANG en_US.utf-8
#|1 RELVER=4.2.1 /bin/sh -c yum -y update       && yum -y install               --setopt=skip_missing_names_on_install=False            bind-utils       epel-release             gettext                 hostname                procps-ng       && yum -y clean all
RUN export RELVER=4.2.1 && yum -y update        && yum -y install               --setopt=skip_missing_names_on_install=False            bind-utils       epel-release             gettext                 hostname                procps-ng       && yum -y clean all
ARG PG_MAJOR
ARG PGDG_REPO_RPM=https://download.postgresql.org/pub/repos/yum/${PG_MAJOR}/redhat/rhel-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
ARG PG_LBL
LABEL postgresql.version.major="${PG_MAJOR}"    postgresql.version="${PG_FULL}"
#|6 BASEVER=4.2.1 PGDG_REPO_RPM=https://download.postgresql.org/pub/repos/yum/11/redhat/rhel-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm PG_FULL=11.6 PG_LBL=11 PG_MAJOR=11 PREFIX=crunchydata /bin/sh -c yum -y install ${PGDG_REPO_RPM}         && sed -i 's/enabled=1/enabled=0/' /etc/yum.repos.d/pgdg*.repo  && yum -y install                 --enablerepo="pgdg${PG_LBL}"            --setopt=skip_missing_names_on_install=False            postgresql${PG_LBL}     && yum -y clean all --enablerepo="pgdg${PG_LBL}"
#RUN export BASEVER=4.2.1 PGDG_REPO_RPM=https://download.postgresql.org/pub/repos/yum/11/redhat/rhel-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm PG_FULL=11.6 PG_LBL=11 PG_MAJOR=11 PREFIX=crunchydata && yum -y install ${PGDG_REPO_RPM}         && sed -i 's/enabled=1/enabled=0/' /etc/yum.repos.d/pgdg*.repo  && yum -y install                 --enablerepo="pgdg${PG_LBL}"            --setopt=skip_missing_names_on_install=False            postgresql${PG_LBL}     && yum -y clean all --enablerepo="pgdg${PG_LBL}"
RUN export BASEVER=4.2.1 PGDG_REPO_RPM=https://download.postgresql.org/pub/repos/yum/11/redhat/rhel-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm PG_FULL=11.6 PG_LBL=11 PG_MAJOR=11 PREFIX=crunchydata && yum -y install ${PGDG_REPO_RPM}       && sed -i 's/enabled=1/enabled=0/' /etc/yum.repos.d/pgdg*.repo  && yum -y clean all --enablerepo="pgdg${PG_LBL}"
COPY pkg/antdb50.tar.gz /tmp/
RUN export PG_MAJOR=11 && mkdir -p /usr/pgsql-${PG_MAJOR} && tar -xf /tmp/antdb50.tar.gz -C /usr/pgsql-${PG_MAJOR} && chmod -R 755 /usr/pgsql-${PG_MAJOR}
ARG PG_MAJOR
ENV PGROOT="/usr/pgsql-${PG_MAJOR}" PGVERSION="${PG_MAJOR}"
ARG BACKREST_VER
ARG PGAUDIT_LBL
#|7 BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata /bin/sh -c yum -y install   --enablerepo="pgdg${PG_MAJOR//.}"         --setopt=skip_missing_names_on_install=False    openssh-clients         openssh-server  pgaudit${PGAUDIT_LBL}   pgbackrest-${BACKREST_VER}        postgresql${PG_MAJOR//.}-contrib        postgresql${PG_MAJOR//.}-server         postgresql${PG_MAJOR//.}-plpython       psmisc  rsync     && yum -y clean all --enablerepo="pgdg${PG_MAJOR//.}"
#RUN export BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata && yum -y install   --enablerepo="pgdg${PG_MAJOR//.}"         --setopt=skip_missing_names_on_install=False    openssh-clients         openssh-server  pgaudit${PGAUDIT_LBL}   pgbackrest-${BACKREST_VER}        postgresql${PG_MAJOR//.}-contrib        postgresql${PG_MAJOR//.}-server         postgresql${PG_MAJOR//.}-plpython       psmisc  rsync     && yum -y clean all --enablerepo="pgdg${PG_MAJOR//.}"
#RUN export BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata && yum -y install   --enablerepo="pgdg${PG_MAJOR//.}"       --setopt=skip_missing_names_on_install=False    openssh-clients         openssh-server  pgaudit${PGAUDIT_LBL}   pgbackrest-${BACKREST_VER}       psmisc  rsync   && yum -y clean all --enablerepo="pgdg${PG_MAJOR//.}"
RUN export BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata && yum -y install   --enablerepo="pgdg${PG_MAJOR//.}"       --setopt=skip_missing_names_on_install=False    openssh-clients         openssh-server  pgbackrest-${BACKREST_VER}       psmisc  rsync   && yum -y clean all --enablerepo="pgdg${PG_MAJOR//.}"
ARG PATRONI_VER
LABEL name="postgres-ha"        summary="PostgreSQL ${PG_FULL} (PGDG) with Patroni"     description="Used for the deployment and management of highly-available PostgreSQL clusters using Patroni."       io.k8s.description="Crunchy PostgreSQL optimized for high-availability (HA)"    io.k8s.display-name="Crunchy PostgreSQL - HA Optimized"   io.openshift.tags="postgresql,postgres,postgis,sql,nosql,database,ha,crunchy"
#|7 BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata /bin/sh -c yum -y install   --enablerepo="pgdg${PG_MAJOR//.}"         --setopt=skip_missing_names_on_install=False    gcc     python3-devel   python3-pip     python3-psycopg2        && yum -y clean all --enablerepo="pgdg${PG_MAJOR//.}"
RUN export BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata && yum -y install    --enablerepo="pgdg${PG_MAJOR//.}"         --setopt=skip_missing_names_on_install=False    gcc     python3-devel   python3-pip     python3-psycopg2        && yum -y clean all --enablerepo="pgdg${PG_MAJOR//.}"
#|7 BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata /bin/sh -c pip3 install --upgrade setuptools python-dateutil  && pip3 install patroni[kubernetes]=="${PATRONI_VER}"
ADD pip3 /tmp/pip3
RUN export BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata && pip3 install --no-index --find-links=/tmp/pip3 --upgrade setuptools python-dateutil  && pip3 install --no-index --find-links=/tmp/pip3 patroni[kubernetes]=="${PATRONI_VER}"
#|7 BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata /bin/sh -c useradd crunchyadm -g 0 -u 17
RUN export BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata && useradd crunchyadm -g 0 -u 17
ENV PATH="${PGROOT}/bin:${PATH}"
#|7 BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata /bin/sh -c mkdir -p /opt/cpm/bin /opt/cpm/conf /pgdata /pgwal /pgconf /backrestrepo /crunchyadm
RUN export BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata && mkdir -p /opt/cpm/bin /opt/cpm/conf /pgdata /pgwal /pgconf /backrestrepo /crunchyadm
#|7 BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata /bin/sh -c chown -R postgres:postgres /opt/cpm /var/lib/pgsql         /pgdata /pgwal /pgconf /backrestrepo /crunchyadm &&     chmod -R g=u /opt/cpm /var/lib/pgsql    /pgdata /pgwal /pgconf /backrestrepo /crunchyadm
RUN export PG_MAJOR=11 && groupadd -g 26 postgres && useradd -g postgres -u 26 postgres && mkdir -p /var/lib/pgsql/${PG_MAJOR}/backups && mkdir -p /var/lib/pgsql/${PG_MAJOR}/data
RUN export BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata && chown -R postgres:postgres /opt/cpm /var/lib/pgsql  /pgdata /pgwal /pgconf /backrestrepo /crunchyadm &&     chmod -R g=u /opt/cpm /var/lib/pgsql    /pgdata /pgwal /pgconf /backrestrepo /crunchyadm
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
#COPY pkg/antdb50.tar.gz /tmp/
#RUN cp -fr /usr/pgsql-11 /usr/pgsql-11-bak && tar -xf /tmp/antdb50.tar.gz -C /usr/pgsql-11 && chmod -R 755 /usr/pgsql-11
ENV LD_LIBRARY_PATH="${PGROOT}/lib:${LD_LIBRARY_PATH}"
#RUN export PG_LBL=11 && yum -y install --enablerepo="pgdg${PG_LBL}"             --setopt=skip_missing_names_on_install=False libkrb5-dev
#RUN export PG_LBL=11 && yum -y install --enablerepo="pgdg${PG_LBL}"            --setopt=skip_missing_names_on_install=False unzip wget && wget https://github.com/pgaudit/pgaudit/archive/1.3.0.zip && unzip 1.3.0.zip && cd pgaudit-1.3.0 && make install USE_PGXS=1 && chmod -R 755 /usr/pgsql-11
VOLUME ["/pgdata", "/pgwal", "/pgconf", "/backrestrepo", "/sshd"]
#RUN echo "alias pg_ctl='pg_ctl -Z gtm_coord'" >> /root/.bashrc && echo "alias postgres='postgres --gtm_coord'" >> /root/.bashrc && source /root/.bashrc
#RUN echo "alias pg_ctl='pg_ctl -Z gtm_coord'" >> /etc/profile && echo "alias postgres='postgres --gtm_coord'" >> /etc/profile && source /etc/profile
COPY pkg/patroni-1.6.3.gc.tar.gz /tmp
RUN pip3 install --no-index --find-links=/tmp/pip3 wheel
RUN pip3 uninstall -y patroni==1.6.3
RUN tar -xf /tmp/patroni-1.6.3.gc.tar.gz -C /tmp && cd /tmp/patroni-1.6.3 && python3 setup.py build && python3 setup.py install
#安装pgbackrest时，自动安装了postgresql11-libs，覆盖了libpq等lib文件。此处重新覆盖一下即可。
RUN export PG_MAJOR=11 && tar -xf /tmp/antdb50.tar.gz -C /usr/pgsql-${PG_MAJOR} && chmod -R 755 /usr/pgsql-${PG_MAJOR}
ENTRYPOINT ["/opt/cpm/bin/bootstrap-postgres-ha.sh"]
USER 26
#RUN echo "alias pg_ctl='pg_ctl -Z gtm_coord'" >> $HOME/.bashrc && echo "alias postgres='postgres --gtm_coord'" >> $HOME/.bashrc && source $HOME/.bashrc
CMD ["/usr/local/bin/patroni"]
#CMD ["tail -f"]
```

## 1.2 构建镜像
```
docker build --build-arg PG_MAJOR=11 --build-arg PG_LBL=11 --build-arg BACKREST_VER=2.20 --build-arg PGAUDIT_LBL=13_11 --build-arg PATRONI_VER=1.6.3 -t crunchydata/antdb.cluster.gc-ha:19.0 -f antdb-ha.df .
```

## 1.3 验证

```
# docker images|grep antdb.cluster.gc-ha
crunchydata/antdb.cluster.gc-ha                                   19.0                 376802826765        2 days ago          693MB
```

## 1.4 将镜像推送至k8s集群的其他主机
若不推送至其他主机，当pod在其他主机启动时，会报 镜像拉取失败 的错误。

有如下两种方式：

1. 推入本地的镜像仓库，其他主机再从本地仓库拉取

2. 使用docker save将镜像保存为本地tar文件，ftp至其他主机后，使用docker load装载

此处，我们使用方式 2。镜像较大，save阶段需耐心等待几分钟。

```
-- 1. 镜像打包并传输至其他主机
# docker save crunchydata/antdb.cluster.gc-ha:19.0 -o /data/antdb.cluster.gc19.0-ha.tar.gz
# scp /data/antdb.cluster.gc19.0-ha.tar.gz root@10.x.x.x:/data
root@10.x.x.x's password: 
/data/antdb.cluster.gc19.0-ha.tar.gz                                                                                                         100%  713MB  78.2MB/s   00:09

-- 2. 其他主机装载镜像
# docker load  -i /data//data/antdb.cluster.gc19.0-ha.tar.gz
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
Loaded image: crunchydata/antdb.cluster.gc-ha:19.0

-- 3. 检查镜像装载是否成功
# docker images|grep antdb.cluster.gc-ha
crunchydata/antdb.cluster.gc-ha                                   19.0                 376802826765        2 days ago          693MB
```

## 2.1 datanode节点的antdb.cluster.db-ha的dockerfile 
**与AntDB单机版的dockerfile改动点说明：**
* 由于加入了PGXC的结构，因此容器的数据库初始化initdb，需要对应新增 --nodename xxx的初始化参数。通过调整容器的启动脚本，在patroni的配置文件中加入- nodename: ${PATRONI_NAME}实现，其中${PATRONI_NAME}为patroni软件的全局环境变量，取值为启动后POD的主机名。
* 由于加入了PGXC的结构，因此容器的原启动方式patroni，需要对应新增 --datanode 的默认启动参数。通过修改patroni代码实现。
* 由于加入了PGXC的结构，因此datanode节点在启动时，需要连接gtm_coord节点。通过 先启动gtm_coord容器，则agtm_host 的ip信息已经确定；再创建一个自定义的configmap(暂定名称 pgo-custom-antdb-config，在此configmap写入agtm_host信息)；最后在创建datanode容器时，通过     --custom-config=pgo-custom-antdb-config 指定到该配置文件集之后，datanode容器启动时，会自动设置agtm_host信息。

```
FROM docker.io/centos:7.7.1908
ARG RELVER="4.2.1"
ARG PG_FULL="11.6"
LABEL vendor="Crunchy Data"     url="https://crunchydata.com"   release="${RELVER}"     org.opencontainers.image.vendor="Crunchy Data"  os.version="7.7"
COPY licenses /licenses
ENV LC_ALL en_US.utf-8
ENV LANG en_US.utf-8
#|1 RELVER=4.2.1 /bin/sh -c yum -y update       && yum -y install               --setopt=skip_missing_names_on_install=False            bind-utils       epel-release             gettext                 hostname                procps-ng       && yum -y clean all
RUN export RELVER=4.2.1 && yum -y update        && yum -y install               --setopt=skip_missing_names_on_install=False            bind-utils       epel-release             gettext                 hostname                procps-ng       && yum -y clean all
ARG PG_MAJOR
ARG PGDG_REPO_RPM=https://download.postgresql.org/pub/repos/yum/${PG_MAJOR}/redhat/rhel-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
ARG PG_LBL
LABEL postgresql.version.major="${PG_MAJOR}"    postgresql.version="${PG_FULL}"
#|6 BASEVER=4.2.1 PGDG_REPO_RPM=https://download.postgresql.org/pub/repos/yum/11/redhat/rhel-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm PG_FULL=11.6 PG_LBL=11 PG_MAJOR=11 PREFIX=crunchydata /bin/sh -c yum -y install ${PGDG_REPO_RPM}         && sed -i 's/enabled=1/enabled=0/' /etc/yum.repos.d/pgdg*.repo  && yum -y install                 --enablerepo="pgdg${PG_LBL}"            --setopt=skip_missing_names_on_install=False            postgresql${PG_LBL}     && yum -y clean all --enablerepo="pgdg${PG_LBL}"
#RUN export BASEVER=4.2.1 PGDG_REPO_RPM=https://download.postgresql.org/pub/repos/yum/11/redhat/rhel-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm PG_FULL=11.6 PG_LBL=11 PG_MAJOR=11 PREFIX=crunchydata && yum -y install ${PGDG_REPO_RPM}         && sed -i 's/enabled=1/enabled=0/' /etc/yum.repos.d/pgdg*.repo  && yum -y install                 --enablerepo="pgdg${PG_LBL}"            --setopt=skip_missing_names_on_install=False            postgresql${PG_LBL}     && yum -y clean all --enablerepo="pgdg${PG_LBL}"
RUN export BASEVER=4.2.1 PGDG_REPO_RPM=https://download.postgresql.org/pub/repos/yum/11/redhat/rhel-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm PG_FULL=11.6 PG_LBL=11 PG_MAJOR=11 PREFIX=crunchydata && yum -y install ${PGDG_REPO_RPM}       && sed -i 's/enabled=1/enabled=0/' /etc/yum.repos.d/pgdg*.repo  && yum -y clean all --enablerepo="pgdg${PG_LBL}"
COPY pkg/antdb50.tar.gz /tmp/
RUN export PG_MAJOR=11 && mkdir -p /usr/pgsql-${PG_MAJOR} && tar -xf /tmp/antdb50.tar.gz -C /usr/pgsql-${PG_MAJOR} && chmod -R 755 /usr/pgsql-${PG_MAJOR}
ARG PG_MAJOR
ENV PGROOT="/usr/pgsql-${PG_MAJOR}" PGVERSION="${PG_MAJOR}"
ARG BACKREST_VER
ARG PGAUDIT_LBL
#|7 BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata /bin/sh -c yum -y install   --enablerepo="pgdg${PG_MAJOR//.}"         --setopt=skip_missing_names_on_install=False    openssh-clients         openssh-server  pgaudit${PGAUDIT_LBL}   pgbackrest-${BACKREST_VER}        postgresql${PG_MAJOR//.}-contrib        postgresql${PG_MAJOR//.}-server         postgresql${PG_MAJOR//.}-plpython       psmisc  rsync     && yum -y clean all --enablerepo="pgdg${PG_MAJOR//.}"
#RUN export BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata && yum -y install   --enablerepo="pgdg${PG_MAJOR//.}"         --setopt=skip_missing_names_on_install=False    openssh-clients         openssh-server  pgaudit${PGAUDIT_LBL}   pgbackrest-${BACKREST_VER}        postgresql${PG_MAJOR//.}-contrib        postgresql${PG_MAJOR//.}-server         postgresql${PG_MAJOR//.}-plpython       psmisc  rsync     && yum -y clean all --enablerepo="pgdg${PG_MAJOR//.}"
#RUN export BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata && yum -y install   --enablerepo="pgdg${PG_MAJOR//.}"       --setopt=skip_missing_names_on_install=False    openssh-clients         openssh-server  pgaudit${PGAUDIT_LBL}   pgbackrest-${BACKREST_VER}       psmisc  rsync   && yum -y clean all --enablerepo="pgdg${PG_MAJOR//.}"
RUN export BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata && yum -y install   --enablerepo="pgdg${PG_MAJOR//.}"       --setopt=skip_missing_names_on_install=False    openssh-clients         openssh-server  pgbackrest-${BACKREST_VER}       psmisc  rsync   && yum -y clean all --enablerepo="pgdg${PG_MAJOR//.}"
ARG PATRONI_VER
LABEL name="postgres-ha"        summary="PostgreSQL ${PG_FULL} (PGDG) with Patroni"     description="Used for the deployment and management of highly-available PostgreSQL clusters using Patroni."       io.k8s.description="Crunchy PostgreSQL optimized for high-availability (HA)"    io.k8s.display-name="Crunchy PostgreSQL - HA Optimized"   io.openshift.tags="postgresql,postgres,postgis,sql,nosql,database,ha,crunchy"
#|7 BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata /bin/sh -c yum -y install   --enablerepo="pgdg${PG_MAJOR//.}"         --setopt=skip_missing_names_on_install=False    gcc     python3-devel   python3-pip     python3-psycopg2        && yum -y clean all --enablerepo="pgdg${PG_MAJOR//.}"
RUN export BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata && yum -y install    --enablerepo="pgdg${PG_MAJOR//.}"         --setopt=skip_missing_names_on_install=False    gcc     python3-devel   python3-pip     python3-psycopg2        && yum -y clean all --enablerepo="pgdg${PG_MAJOR//.}"
#|7 BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata /bin/sh -c pip3 install --upgrade setuptools python-dateutil  && pip3 install patroni[kubernetes]=="${PATRONI_VER}"
ADD pip3 /tmp/pip3
RUN export BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata && pip3 install --no-index --find-links=/tmp/pip3 --upgrade setuptools python-dateutil  && pip3 install --no-index --find-links=/tmp/pip3 patroni[kubernetes]=="${PATRONI_VER}"
#|7 BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata /bin/sh -c useradd crunchyadm -g 0 -u 17
RUN export BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata && useradd crunchyadm -g 0 -u 17
ENV PATH="${PGROOT}/bin:${PATH}"
#|7 BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata /bin/sh -c mkdir -p /opt/cpm/bin /opt/cpm/conf /pgdata /pgwal /pgconf /backrestrepo /crunchyadm
RUN export BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata && mkdir -p /opt/cpm/bin /opt/cpm/conf /pgdata /pgwal /pgconf /backrestrepo /crunchyadm
#|7 BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata /bin/sh -c chown -R postgres:postgres /opt/cpm /var/lib/pgsql         /pgdata /pgwal /pgconf /backrestrepo /crunchyadm &&     chmod -R g=u /opt/cpm /var/lib/pgsql    /pgdata /pgwal /pgconf /backrestrepo /crunchyadm
RUN export PG_MAJOR=11 && groupadd -g 26 postgres && useradd -g postgres -u 26 postgres && mkdir -p /var/lib/pgsql/${PG_MAJOR}/backups && mkdir -p /var/lib/pgsql/${PG_MAJOR}/data
RUN export BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata && chown -R postgres:postgres /opt/cpm /var/lib/pgsql  /pgdata /pgwal /pgconf /backrestrepo /crunchyadm &&     chmod -R g=u /opt/cpm /var/lib/pgsql    /pgdata /pgwal /pgconf /backrestrepo /crunchyadm
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
#COPY pkg/antdb50.tar.gz /tmp/
#RUN cp -fr /usr/pgsql-11 /usr/pgsql-11-bak && tar -xf /tmp/antdb50.tar.gz -C /usr/pgsql-11 && chmod -R 755 /usr/pgsql-11
ENV LD_LIBRARY_PATH="${PGROOT}/lib:${LD_LIBRARY_PATH}"
#RUN export PG_LBL=11 && yum -y install --enablerepo="pgdg${PG_LBL}"             --setopt=skip_missing_names_on_install=False libkrb5-dev
#RUN export PG_LBL=11 && yum -y install --enablerepo="pgdg${PG_LBL}"            --setopt=skip_missing_names_on_install=False unzip wget && wget https://github.com/pgaudit/pgaudit/archive/1.3.0.zip && unzip 1.3.0.zip && cd pgaudit-1.3.0 && make install USE_PGXS=1 && chmod -R 755 /usr/pgsql-11
VOLUME ["/pgdata", "/pgwal", "/pgconf", "/backrestrepo", "/sshd"]
COPY pkg/patroni-1.6.3.db.tar.gz /tmp
RUN pip3 install --no-index --find-links=/tmp/pip3 wheel
RUN pip3 uninstall -y patroni==1.6.3
RUN tar -xf /tmp/patroni-1.6.3.db.tar.gz -C /tmp && cd /tmp/patroni-1.6.3 && python3 setup.py build && python3 setup.py install
#安装pgbackrest时，自动安装了postgresql11-libs，覆盖了libpq等lib文件。此处重新覆盖一下即可。
RUN export PG_MAJOR=11 && tar -xf /tmp/antdb50.tar.gz -C /usr/pgsql-${PG_MAJOR} && chmod -R 755 /usr/pgsql-${PG_MAJOR}
ENTRYPOINT ["/opt/cpm/bin/bootstrap-postgres-ha.sh"]
USER 26
CMD ["/usr/local/bin/patroni"]
```

## 2.2 构建镜像
```
docker build --build-arg PG_MAJOR=11 --build-arg PG_LBL=11 --build-arg BACKREST_VER=2.20 --build-arg PGAUDIT_LBL=13_11 --build-arg PATRONI_VER=1.6.3 -t crunchydata/antdb.cluster.db-ha:19.0 -f antdb-ha.df .
```

## 2.3 验证

```
# docker images|grep antdb.cluster.db-ha
crunchydata/antdb.cluster.db-ha                                   19.0                 376802826765        2 days ago          693MB
```

## 2.4 将镜像推送至k8s集群的其他主机
若不推送至其他主机，当pod在其他主机启动时，会报 镜像拉取失败 的错误。

有如下两种方式：

1. 推入本地的镜像仓库，其他主机再从本地仓库拉取

2. 使用docker save将镜像保存为本地tar文件，ftp至其他主机后，使用docker load装载

此处，我们使用方式 2。镜像较大，save阶段需耐心等待几分钟。

```
-- 1. 镜像打包并传输至其他主机
# docker save crunchydata/antdb.cluster.db-ha:19.0 -o /data/antdb.cluster.db19.0-ha.tar.gz
# scp /data/antdb.cluster.db19.0-ha.tar.gz root@10.x.x.x:/data
root@10.x.x.x's password: 
/data/antdb.cluster.db19.0-ha.tar.gz                                                                                                         100%  713MB  78.2MB/s   00:09

-- 2. 其他主机装载镜像
# docker load  -i /data//data/antdb.cluster.db19.0-ha.tar.gz
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
Loaded image: crunchydata/antdb.cluster.db-ha:19.0

-- 3. 检查镜像装载是否成功
# docker images|grep antdb.cluster.db-ha
crunchydata/antdb.cluster.db-ha                                   19.0                 376802826765        2 days ago          693MB
```

## 3.1 coordinator节点的antdb.cluster.cn-ha的dockerfile 
**与AntDB单机版的dockerfile改动点说明：**
* 由于加入了PGXC的结构，因此容器的数据库初始化initdb，需要对应新增 --nodename xxx的初始化参数。通过调整容器的启动脚本，在patroni的配置文件中加入- nodename: ${PATRONI_NAME}实现，其中${PATRONI_NAME}为patroni软件的全局环境变量，取值为启动后POD的主机名。
* 由于加入了PGXC的结构，因此容器的原启动方式patroni，需要对应新增 --coordinator 的默认启动参数。通过修改patroni代码实现。
* 由于加入了PGXC的结构，因此coordinator节点在启动时，需要连接gtm_coord节点。通过 先启动gtm_coord容器，则agtm_host 的ip信息已经确定；再创建一个自定义的configmap(暂定名称 pgo-custom-antdb-config，在此configmap写入agtm_host信息)；最后在创建coordinator容器时，通过     --custom-config=pgo-custom-antdb-config 指定到该配置文件集之后，coordinator容器启动时，会自动设置agtm_host信息。

```
FROM docker.io/centos:7.7.1908
ARG RELVER="4.2.1"
ARG PG_FULL="11.6"
LABEL vendor="Crunchy Data"     url="https://crunchydata.com"   release="${RELVER}"     org.opencontainers.image.vendor="Crunchy Data"  os.version="7.7"
COPY licenses /licenses
ENV LC_ALL en_US.utf-8
ENV LANG en_US.utf-8
#|1 RELVER=4.2.1 /bin/sh -c yum -y update       && yum -y install               --setopt=skip_missing_names_on_install=False            bind-utils       epel-release             gettext                 hostname                procps-ng       && yum -y clean all
RUN export RELVER=4.2.1 && yum -y update        && yum -y install               --setopt=skip_missing_names_on_install=False            bind-utils       epel-release             gettext                 hostname                procps-ng       && yum -y clean all
ARG PG_MAJOR
ARG PGDG_REPO_RPM=https://download.postgresql.org/pub/repos/yum/${PG_MAJOR}/redhat/rhel-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
ARG PG_LBL
LABEL postgresql.version.major="${PG_MAJOR}"    postgresql.version="${PG_FULL}"
#|6 BASEVER=4.2.1 PGDG_REPO_RPM=https://download.postgresql.org/pub/repos/yum/11/redhat/rhel-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm PG_FULL=11.6 PG_LBL=11 PG_MAJOR=11 PREFIX=crunchydata /bin/sh -c yum -y install ${PGDG_REPO_RPM}         && sed -i 's/enabled=1/enabled=0/' /etc/yum.repos.d/pgdg*.repo  && yum -y install                 --enablerepo="pgdg${PG_LBL}"            --setopt=skip_missing_names_on_install=False            postgresql${PG_LBL}     && yum -y clean all --enablerepo="pgdg${PG_LBL}"
#RUN export BASEVER=4.2.1 PGDG_REPO_RPM=https://download.postgresql.org/pub/repos/yum/11/redhat/rhel-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm PG_FULL=11.6 PG_LBL=11 PG_MAJOR=11 PREFIX=crunchydata && yum -y install ${PGDG_REPO_RPM}         && sed -i 's/enabled=1/enabled=0/' /etc/yum.repos.d/pgdg*.repo  && yum -y install                 --enablerepo="pgdg${PG_LBL}"            --setopt=skip_missing_names_on_install=False            postgresql${PG_LBL}     && yum -y clean all --enablerepo="pgdg${PG_LBL}"
RUN export BASEVER=4.2.1 PGDG_REPO_RPM=https://download.postgresql.org/pub/repos/yum/11/redhat/rhel-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm PG_FULL=11.6 PG_LBL=11 PG_MAJOR=11 PREFIX=crunchydata && yum -y install ${PGDG_REPO_RPM}       && sed -i 's/enabled=1/enabled=0/' /etc/yum.repos.d/pgdg*.repo  && yum -y clean all --enablerepo="pgdg${PG_LBL}"
COPY pkg/antdb50.tar.gz /tmp/
RUN export PG_MAJOR=11 && mkdir -p /usr/pgsql-${PG_MAJOR} && tar -xf /tmp/antdb50.tar.gz -C /usr/pgsql-${PG_MAJOR} && chmod -R 755 /usr/pgsql-${PG_MAJOR}
ARG PG_MAJOR
ENV PGROOT="/usr/pgsql-${PG_MAJOR}" PGVERSION="${PG_MAJOR}"
ARG BACKREST_VER
ARG PGAUDIT_LBL
#|7 BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata /bin/sh -c yum -y install   --enablerepo="pgdg${PG_MAJOR//.}"         --setopt=skip_missing_names_on_install=False    openssh-clients         openssh-server  pgaudit${PGAUDIT_LBL}   pgbackrest-${BACKREST_VER}        postgresql${PG_MAJOR//.}-contrib        postgresql${PG_MAJOR//.}-server         postgresql${PG_MAJOR//.}-plpython       psmisc  rsync     && yum -y clean all --enablerepo="pgdg${PG_MAJOR//.}"
#RUN export BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata && yum -y install   --enablerepo="pgdg${PG_MAJOR//.}"         --setopt=skip_missing_names_on_install=False    openssh-clients         openssh-server  pgaudit${PGAUDIT_LBL}   pgbackrest-${BACKREST_VER}        postgresql${PG_MAJOR//.}-contrib        postgresql${PG_MAJOR//.}-server         postgresql${PG_MAJOR//.}-plpython       psmisc  rsync     && yum -y clean all --enablerepo="pgdg${PG_MAJOR//.}"
#RUN export BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata && yum -y install   --enablerepo="pgdg${PG_MAJOR//.}"       --setopt=skip_missing_names_on_install=False    openssh-clients         openssh-server  pgaudit${PGAUDIT_LBL}   pgbackrest-${BACKREST_VER}       psmisc  rsync   && yum -y clean all --enablerepo="pgdg${PG_MAJOR//.}"
RUN export BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata && yum -y install   --enablerepo="pgdg${PG_MAJOR//.}"       --setopt=skip_missing_names_on_install=False    openssh-clients         openssh-server  pgbackrest-${BACKREST_VER}       psmisc  rsync   && yum -y clean all --enablerepo="pgdg${PG_MAJOR//.}"
ARG PATRONI_VER
LABEL name="postgres-ha"        summary="PostgreSQL ${PG_FULL} (PGDG) with Patroni"     description="Used for the deployment and management of highly-available PostgreSQL clusters using Patroni."       io.k8s.description="Crunchy PostgreSQL optimized for high-availability (HA)"    io.k8s.display-name="Crunchy PostgreSQL - HA Optimized"   io.openshift.tags="postgresql,postgres,postgis,sql,nosql,database,ha,crunchy"
#|7 BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata /bin/sh -c yum -y install   --enablerepo="pgdg${PG_MAJOR//.}"         --setopt=skip_missing_names_on_install=False    gcc     python3-devel   python3-pip     python3-psycopg2        && yum -y clean all --enablerepo="pgdg${PG_MAJOR//.}"
RUN export BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata && yum -y install    --enablerepo="pgdg${PG_MAJOR//.}"         --setopt=skip_missing_names_on_install=False    gcc     python3-devel   python3-pip     python3-psycopg2        && yum -y clean all --enablerepo="pgdg${PG_MAJOR//.}"
#|7 BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata /bin/sh -c pip3 install --upgrade setuptools python-dateutil  && pip3 install patroni[kubernetes]=="${PATRONI_VER}"
ADD pip3 /tmp/pip3
RUN export BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata && pip3 install --no-index --find-links=/tmp/pip3 --upgrade setuptools python-dateutil  && pip3 install --no-index --find-links=/tmp/pip3 patroni[kubernetes]=="${PATRONI_VER}"
#|7 BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata /bin/sh -c useradd crunchyadm -g 0 -u 17
RUN export BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata && useradd crunchyadm -g 0 -u 17
ENV PATH="${PGROOT}/bin:${PATH}"
#|7 BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata /bin/sh -c mkdir -p /opt/cpm/bin /opt/cpm/conf /pgdata /pgwal /pgconf /backrestrepo /crunchyadm
RUN export BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata && mkdir -p /opt/cpm/bin /opt/cpm/conf /pgdata /pgwal /pgconf /backrestrepo /crunchyadm
#|7 BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata /bin/sh -c chown -R postgres:postgres /opt/cpm /var/lib/pgsql         /pgdata /pgwal /pgconf /backrestrepo /crunchyadm &&     chmod -R g=u /opt/cpm /var/lib/pgsql    /pgdata /pgwal /pgconf /backrestrepo /crunchyadm
RUN export PG_MAJOR=11 && groupadd -g 26 postgres && useradd -g postgres -u 26 postgres && mkdir -p /var/lib/pgsql/${PG_MAJOR}/backups && mkdir -p /var/lib/pgsql/${PG_MAJOR}/data
RUN export BACKREST_VER=2.20 BASEVER=4.2.1 PATRONI_VER=1.6.3 PGAUDIT_LBL=13_11 PG_FULL=11.6 PG_MAJOR=11 PREFIX=crunchydata && chown -R postgres:postgres /opt/cpm /var/lib/pgsql  /pgdata /pgwal /pgconf /backrestrepo /crunchyadm &&     chmod -R g=u /opt/cpm /var/lib/pgsql    /pgdata /pgwal /pgconf /backrestrepo /crunchyadm
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
#COPY pkg/antdb50.tar.gz /tmp/
#RUN cp -fr /usr/pgsql-11 /usr/pgsql-11-bak && tar -xf /tmp/antdb50.tar.gz -C /usr/pgsql-11 && chmod -R 755 /usr/pgsql-11
ENV LD_LIBRARY_PATH="${PGROOT}/lib:${LD_LIBRARY_PATH}"
#RUN export PG_LBL=11 && yum -y install --enablerepo="pgdg${PG_LBL}"             --setopt=skip_missing_names_on_install=False libkrb5-dev
#RUN export PG_LBL=11 && yum -y install --enablerepo="pgdg${PG_LBL}"            --setopt=skip_missing_names_on_install=False unzip wget && wget https://github.com/pgaudit/pgaudit/archive/1.3.0.zip && unzip 1.3.0.zip && cd pgaudit-1.3.0 && make install USE_PGXS=1 && chmod -R 755 /usr/pgsql-11
VOLUME ["/pgdata", "/pgwal", "/pgconf", "/backrestrepo", "/sshd"]
COPY pkg/patroni-1.6.3.cn.tar.gz /tmp
RUN pip3 install --no-index --find-links=/tmp/pip3 wheel
RUN pip3 uninstall -y patroni==1.6.3
RUN tar -xf /tmp/patroni-1.6.3.cn.tar.gz -C /tmp && cd /tmp/patroni-1.6.3 && python3 setup.py build && python3 setup.py install
#安装pgbackrest时，自动安装了postgresql11-libs，覆盖了libpq等lib文件。此处重新覆盖一下即可。
RUN export PG_MAJOR=11 && tar -xf /tmp/antdb50.tar.gz -C /usr/pgsql-${PG_MAJOR} && chmod -R 755 /usr/pgsql-${PG_MAJOR}
#RUN yum -y install gdb lrzsz
ENTRYPOINT ["/opt/cpm/bin/bootstrap-postgres-ha.sh"]
USER 26
CMD ["/usr/local/bin/patroni"]
```

## 3.2 构建镜像
```
docker build --build-arg PG_MAJOR=11 --build-arg PG_LBL=11 --build-arg BACKREST_VER=2.20 --build-arg PGAUDIT_LBL=13_11 --build-arg PATRONI_VER=1.6.3 -t crunchydata/antdb.cluster.cn-ha:19.0 -f antdb-ha.df .
```

## 3.3 验证

```
# docker images|grep antdb.cluster.cn-ha
crunchydata/antdb.cluster.cn-ha                                   19.0                 376802826765        2 days ago          693MB
```

## 3.4 将镜像推送至k8s集群的其他主机
若不推送至其他主机，当pod在其他主机启动时，会报 镜像拉取失败 的错误。

有如下两种方式：

1. 推入本地的镜像仓库，其他主机再从本地仓库拉取

2. 使用docker save将镜像保存为本地tar文件，ftp至其他主机后，使用docker load装载

此处，我们使用方式 2。镜像较大，save阶段需耐心等待几分钟。

```
-- 1. 镜像打包并传输至其他主机
# docker save crunchydata/antdb.cluster.cn-ha:19.0 -o /data/antdb.cluster.cn19.0-ha.tar.gz
# scp /data/antdb.cluster.cn19.0-ha.tar.gz root@10.x.x.x:/data
root@10.x.x.x's password: 
/data/antdb.cluster.cn19.0-ha.tar.gz                                                                                                         100%  713MB  78.2MB/s   00:09

-- 2. 其他主机装载镜像
# docker load  -i /data//data/antdb.cluster.cn19.0-ha.tar.gz
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
Loaded image: crunchydata/antdb.cluster.cn-ha:19.0

-- 3. 检查镜像装载是否成功
# docker images|grep antdb.cluster.cn-ha
crunchydata/antdb.cluster.cn-ha                                   19.0                 376802826765        2 days ago          693MB
```

## 4 验证
最终会有3个镜像，分别对应AntDB集群版的3个组件：gtm_coord/coordinator/datanode
```
# docker images|grep antdb.cluster.|grep '19.0'
crunchydata/antdb.cluster.cn-ha                      19.0                49cbada5ce9b        2 days ago          693MB
crunchydata/antdb.cluster.gc-ha                      19.0                376802826765        2 days ago          693MB
crunchydata/antdb.cluster.db-ha                      19.0                8860923e905d        2 days ago          693MB
```

# 初始化operator环境
包括：

* 清理全部namespace
* 重建namespace
* 重建PV
* 创建k8s的用户认证
* 创建访问权限
* 部署postgres-operator
* 设置postgres-operator的API的环境变量，用于后续pgo客户端访问k8s
* 为创建AntDB集群的应用创建自己的k8s用户

**上述的工作均为后续创建AntDB集群准备一个干净的初始环境。**

上述所有步骤，均已通过shell实现，直接执行即可
```
# sh init_pgo.sh
```

init_pgo.sh 脚本内容
```
#!/bin/bash

cd $PGOROOT
make cleannamespaces
make setupnamespaces
$PGOROOT/pv/create-pv.sh
$PGOROOT/deploy/install-bootstrap-creds.sh
make installrbac
make deployoperator

kubectl get service postgres-operator -n pgo
kubectl get pod --selector=name=postgres-operator -n pgo
sleep 20
cluster_ip=$(kubectl get service postgres-operator -n pgo --no-headers=true|awk '{print $3}')
sed -i "s#export PGO_APISERVER_URL=https://[0-9].*#export PGO_APISERVER_URL=https://${cluster_ip}:${PGO_APISERVER_PORT}#g" ~/.bashrc
source ~/.bashrc
sed -i 's/someuser:somepassword/pgoadmin:examplepassword/g' ~/.pgouser
pgo create pgouser someuser --pgouser-namespaces="pgouser1,pgouser2" --pgouser-password=somepassword --pgouser-roles="pgoadmin"
sed -i 's/pgoadmin:examplepassword/someuser:somepassword/g' ~/.pgouser
```

**待完善的地方：**

* postgres-operator 启动并对外提供服务需要一定的时间，脚本暂时通过sleep 20 休眠20s的方式，来获取其对外提供的ip，有很大可能还是会获取失败。后续通过判断postgres-operator的状态来保证100%可以成功获取ip信息。
* 为AntDB集群创建的k8s用户固定为pgouser1/pgouser2，后续改为更灵活的方式。

# 创建 AntDB集群应用
包括：

* 调整配置文件antdb_info.txt，默认情况下提供4个参数即可，分别为：AntDB集群各组件(gc/cn/db)部署的数量、各组件对应镜像名称、各组件对应镜像的版本号、AntDB集群部署至k8s的哪个namespace
* 创建gc的所有pod
* 创建db的所有pod
* 创建cn的所有pod
* 自动初始化所有gc/cn的pgxc_node信息
* 删除某个coordinator的pod后，提供脚本自动刷新所有gc/cn的pgxc_node信息，删除old cn的信息，添加new cn的信息
* 新增coordinator的pod后，脚本也可以自动刷新所有gc/cn的pgxc_node信息

上述所有步骤，均已通过shell实现，直接执行即可。执行后，即可连接gc/cn使用AntDB集群。
```
# sh create_antdb.sh
```

**待完善的地方：**

* PV删除后，PV对应的主机上的文件并未删除。后续继续使用该PV创建pod，patroni不会调用initdb，而是直接pg_ctl start启动。
* pod 重启后，ip会发生变更，无法自动更新pgxc_node信息
* gtm_coord 的pod重启后，ip发生变更，无法自动更新cn/db节点的agtm_host 的配置信息

**上述2个地方，应该是operator需要干的活，后续需要完善上面2个点。非常重要的2个点。**

验证 antdb 集群应用部署是否成功
```
# kubectl get pod -n pgouser1 --no-headers=false|grep -Ev '[a-z A-Z 0-9]+[-][a-z A-Z 0-9]+[-][a-z A-Z 0-9]+[-][a-z A-Z 0-9]+'
cn1-69457578b8-9mmxx                        1/1   Running     0     40h
cn2-7fbffbc99d-9bp8p                        1/1   Running     0     40h
cn3-6b5bc48f7b-sp4g2                        1/1   Running     0     40h
dn1-f6f6f8fcd-25hk8                         1/1   Running     0     40h
dn2-6856c56dc4-sbsv6                        1/1   Running     0     40h
dn3-6695d4c578-88w5f                        1/1   Running     0     40h
dn4-6fc67d8b86-lgn8s                        1/1   Running     0     40h
dn5-95c5fdc6-kxsn5                          1/1   Running     0     40h
dn6-6f78ff848d-c5xbx                        1/1   Running     0     40h
gc-8db98898c-x6k8f                          1/1   Running     0     40h
```

antdb_info.txt 配置文件内容
```
#gtm_coord/coordinator/datanode,下列所有数组均按该顺序设置

#节点数量
num_node=(1 3 6)

#各组件使用的镜像相关信息
#镜像前缀
image_prefix="crunchydata"
#镜像名称
image_name=("antdb.cluster.gc-ha" "antdb.cluster.cn-ha" "antdb.cluster.db-ha")
#镜像版本号
image_version=("19.0" "19.0" "19.0")

#k8s 使用的namespace名称
namespace="pgouser1"
```

create_antdb.sh 脚本内容
```
#!/bin/bash

source ./antdb_info.txt
ip_gtmcoord_pod=""
#由于pgo create cluster gc，启动pod需要一定时间，在创建pod后，立即查询该pod的ip会失败，因此设定一个默认30s的超时时间
timeout_if_gtm_coord_is_running=30

create_gtm_coord()
{
  cluster_name_gc="gc"
  pgo create cluster ${cluster_name_gc}  --ccp-image=${image_name[0]} --ccp-image-tag=${image_version[0]} --namespace=${namespace}
}

get_gtm_coord_host_ip()
{
  cluster_name_gc="gc"
  rst=
  for ((k=1; k<=${timeout_if_gtm_coord_is_running}; k++))
  do
    name_gtmcoord_pod=$(pgo test ${cluster_name_gc} -n ${namespace} -o json|grep "${cluster_name_gc}-"|awk -F'"' '{print $4}')
    if [ "x${name_gtmcoord_pod}" == "x" ];then
      echo "cluster ${cluster_name_gc} is not running or not created!!!"
      rst=1
    else
      ip_gtmcoord_pod=$(kubectl exec -it ${name_gtmcoord_pod} -n pgouser1 -- hostname -i)
      if [ "x${ip_gtmcoord_pod}" != "x" ];then
        echo "cluster ${cluster_name_gc} is running,ip is :"${ip_gtmcoord_pod}
        rst=0
        return $rst
      else
        echo "cluster ${cluster_name_gc} is running,but ip is not up,keep waiting."
        rst=1
      fi
    fi
    sleep 1
  done
  return $rst
}

if_custom_config_exist()
{
  custom_config=$1
  kubectl get configmap -n ${namespace}|grep ${custom_config} > /dev/null
  if [ "$?" == "0" ];then
    return 0
  else
    return 1
  fi
}

create_custom_config()
{
  custom_config=$1
  config_file="$PGOROOT/examples/custom-config/postgres-ha.yaml"
  if get_gtm_coord_host_ip ;then
    sed -i "s/agtm_host: .*$/agtm_host: '${ip_gtmcoord_pod}'/g" ${config_file} > /dev/null
    export PGO_NAMESPACE=${namespace}
    $PGOROOT/examples/custom-config/create.sh
  else
    echo "please create the pod of gtm_coord first!"
    exit 1
  fi
}

create_datanode()
{
  cluster_name_db=$1
  custom_config="pgo-custom-antdb-config"
  if if_custom_config_exist ${custom_config};then
    pgo create cluster ${cluster_name_db} --ccp-image=${image_name[2]} --ccp-image-tag=${image_version[2]} --namespace=${namespace} --custom-config=${custom_config}
  else
    create_custom_config ${custom_config}
    pgo create cluster ${cluster_name_db} --ccp-image=${image_name[2]} --ccp-image-tag=${image_version[2]} --namespace=${namespace} --custom-config=${custom_config}
  fi
}

create_datanode_all()
{
  cluster_name_db_prefix="dn"
  for ((i=1; i<=${num_node[2]}; i++))
  do
    create_datanode "${cluster_name_db_prefix}$i"
  done
}

create_coordinator()
{
  cluster_name_cn=$1
  custom_config="pgo-custom-antdb-config"
  if if_custom_config_exist ${custom_config};then
    pgo create cluster ${cluster_name_cn} --ccp-image=${image_name[1]} --ccp-image-tag=${image_version[1]} --namespace=${namespace} --custom-config=${custom_config}
  else
    create_custom_config ${custom_config}
    pgo create cluster ${cluster_name_cn} --ccp-image=${image_name[1]} --ccp-image-tag=${image_version[1]} --namespace=${namespace} --custom-config=${custom_config}
  fi
}

create_create_coordinator_all()
{
  cluster_name_cn_prefix="cn"
  for ((i=1; i<=${num_node[1]}; i++))
  do
    create_coordinator "${cluster_name_cn_prefix}$i"
  done
}

create_gtm_coord
create_datanode_all
create_create_coordinator_all
sh ./init_pgxc_node.sh
```
# 创建 AntDB集群应用的步骤总结
简单3个步骤即可完成一个AntDB集群的部署，整个过程不超过5分钟。
```
1. 初始化operator的环境
sh init_pgo.sh

2. 调整AntDB集群的总配置信息
#vim antdb_info.txt 
#gtm_coord/coordinator/datanode,下列所有数组均按该顺序设置

#节点数量
num_node=(1 3 6)

#各组件使用的镜像相关信息
#镜像前缀
image_prefix="crunchydata"
#镜像名称
image_name=("antdb.cluster.gc-ha" "antdb.cluster.cn-ha" "antdb.cluster.db-ha")
#镜像版本号
image_version=("19.0" "19.0" "19.0")

#k8s 使用的namespace名称
namespace="pgouser1"

3. 创建AntDB集群，并初始化pgxc_node信息
sh create_antdb.sh

至此，AntDB集群部署完毕。
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
psql (5.0.0 a8a0374 based on PG 11.6)
Type "help" for help.

postgres=# select version();
                                                          version                                                          
---------------------------------------------------------------------------------------------------------------------------
 PostgreSQL 11.6 ADB 5.0.0 a8a0374 on x86_64-pc-linux-gnu, compiled by gcc (GCC) 4.8.5 20150623 (Red Hat 4.8.5-36), 64-bit
(1 row)

postgres=# alter user postgres password 'xxxxxx';
ALTER ROLE

postgres=# \l
                                  List of databases
   Name    |  Owner   | Encoding |   Collate   |    Ctype    |   Access privileges   
-----------+----------+----------+-------------+-------------+-----------------------
 antdb     | postgres | UTF8     | en_US.utf-8 | en_US.utf-8 | 
 postgres  | postgres | UTF8     | en_US.utf-8 | en_US.utf-8 | 
 template0 | postgres | UTF8     | en_US.utf-8 | en_US.utf-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
 template1 | postgres | UTF8     | en_US.utf-8 | en_US.utf-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
(4 rows)

postgres=# \du
                                   List of roles
 Role name |                         Attributes                         | Member of 
-----------+------------------------------------------------------------+-----------
 postgres  | Superuser, Create role, Create DB, Replication, Bypass RLS | {}


```

4. 修改密码后，可使用 虚拟ip访问了

退出该容器，使用psql连接虚拟ip访问

```
# psql -h 172.30.53.29 -p 5432 -d postgres -U postgres
Password for user postgres: 
psql (11.5, server 11.6)
Type "help" for help.

postgres=# 
```

5. 也可以使用k8s的CLUSTER-IP 访问

```
--获取CLUSTER-IP的地址
# kubectl get service -n pgouser1
NAME                           TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                                         AGE
antdb                        ClusterIP   10.254.230.242   <none>        5432/TCP,10000/TCP,2022/TCP,9187/TCP,8009/TCP   74m
antdb-backrest-shared-repo   ClusterIP   10.254.122.152   <none>        2022/TCP                                        74m

--通过CLUSTER-IP访问AntDB服务
# psql -h 10.254.230.242 -p 5432 -d postgres -U postgres
Password for user testuser: 
psql (11.5, server 11.6)
Type "help" for help.

postgres=# 
```

# 遇到的问题
## 1. patroni启动时，默认参数没有PGXC的节点类型，需修改patroni的代码

**问题现象**
```
```

**错误原因** 单PG和PGXC结构差异导致

**解决方式** 

调整patroni代码，修改其启动时的运行参数列表 

## 2. initdb时，默认参数没有nodename，需修改patroni的yaml配置文件

**问题现象**
```
```

**错误原因** 单PG和PGXC结构差异导致

**解决方式** 

调整patroni的yaml配置文件，并以pod的主机名作为nodename传入initdb来初始化数据库。

## 3. cn/db节点启动时，需配置agtm_host的参数，通过自定义configmap的方式解决

**问题现象**
```
```

**错误原因** 单PG和PGXC结构差异导致

**解决方式** 

先启动gc的pod，得到一个确切的gc组件的ip地址；
接着创建自定义的configmap；
最后在创建cn/db节点时，通过--custom-config=pgo-custom-antdb-config 指定configmap的方式实现。

# 必须解决的遗留问题
1. pod 重启后，ip会发生变更，无法自动更新pgxc_node信息
2. gtm_coord 的pod重启后，ip发生变更，无法自动更新cn/db节点的agtm_host 的配置信息

# 总结
AntDB 集群版镜像已部署成功，是一个没有slave节点的最基本的集群。

另外，还有2个必须解决的重要遗留问题。

# 参考
AntDB QQ群号：496464280

[AntDB github链接](https://github.com/ADBSQL)