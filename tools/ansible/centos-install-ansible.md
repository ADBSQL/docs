#  ansible的安装使用

> 使用仅针对AntDB的场景

在集群主机数量比较多的时候(多于10台)，部署AntDB前的准备工作会比较麻烦，比如创建用户、修改用户profile、修改操作系统参数等，所以引入ansible来解决这个问题。

#### 为何是ansible

Ansible 是一个配置管理和应用部署工具，功能类似于目前业界的配置管理工具 Chef,Puppet,Saltstack。Ansible 是通过 Python 语言开发。Ansible 平台由 Michael DeHaan 创建，他同时也是知名软件 Cobbler 与 Func 的作者。Ansible 的第一个版本发布于 2012 年 2 月。Ansible 默认通过 SSH 协议管理机器，所以 Ansible 不需要安装客户端程序在服务器上。您只需要将 Ansible 安装在一台服务器，在 Ansible 安装完后，您就可以去管理控制其它服务器。不需要为它配置数据库，Ansible 不会以 daemons 方式来启动或保持运行状态。Ansible 可以实现以下目标：

- 自动化部署应用
- 自动化管理配置
- 自动化的持续交付
- 自动化的（AWS）云服务管理。

根据 Ansible 官方提供的信息，当前使用 Ansible 的用户有：evernote、rackspace、NASA、Atlassian、twitter 等。

根据描述，关键部分是：`Ansible 默认通过 SSH 协议管理机器，所以 Ansible 不需要安装客户端程序在服务器上。您只需要将 Ansible 安装在一台服务器，在 Ansible 安装完后，您就可以去管理控制其它服务器`。

在部署的时候，建议跟adbmgr放在同一台主机上。

#### 离线安装ansible （root）

在客户现场的环境中，最多只能配置与OS版本一致的yum源，很多时候并没有外网，所以在引入额外工具的时候，需要考虑在内网环境如何方便的进行安装。

大致思路是：

1. 离线环境中安装setuptools和pip
2.  在在线环境通过pip将paramiko的依赖下载到一个文件夹里
3. 在离线环境中，通过pip访问该文件夹来解决依赖问题，顺利安装。

首先，离线环境中，需要安装setuptools和pip：(root)

```shell
unzip setuptools-39.1.0.zip
cd setuptools-39.1.0 && $SUDO python setup.py install 
cd ..
tar xzvf pip-10.0.1.tar.gz
cd pip-10.0.1 && $SUDO python setup.py install 
cd ..
```

在在线环境中，下载ansible的依赖：

```
mkdir -p ~/ansible_soft
pip download -d ~/ansible_soft ansible
```

下载目录打包：

```
tar czvf ansible_soft.tar.gz ansible_soft
```

上传到离线环境解压，通过pip 安装：(root)

```
pip install --no-index --ignore-installed  --find-links=ansible_soft ansible
```

验证是否安装成功：

```
ansible --version
```

#### 配置ansible （root）

我们使用的场景比较简单，只需要将集群中涉及到的机器配置在`/etc/ansible/hosts`文件中即可。

```shell
vi /etc/ansible/hosts,添加如下内容：
[antdb1]
10.1.226.455
[antdb1:vars]
ansible_ssh_user=root
ansible_ssh_pass=pass1


[antdb2]
10.1.226.456
[antdb2:vars]
ansible_ssh_user=root
ansible_ssh_pass=pass2


[antdb3]
10.1.226.457
[antdb3:vars]
ansible_ssh_user=root
ansible_ssh_pass=pass3

[antdb4]
10.1.226.458
[antdb3:vars]
ansible_ssh_user=root
ansible_ssh_pass=pass4

```

> 因为密码不同，所以示例中根据密码将主机分组。

配置root 用户的ssh免密认证

```
export ANSIBLE_HOST_KEY_CHECKING=False
ansible all -m authorized_key -a "user=root key='{{ lookup('file', '/root/.ssh/id_rsa.pub') }}' path=/root/.ssh/authorized_keys manage_dir=no"
```

上述命令在ansible中称之为一个ad-hoc，其中：

- -m 指定使用哪个模块
- -a 指定模块的参数

验证：

```shell
[root@intel175 ansible]# ansible all -m command -a "hostname"
10.20.16.455 | CHANGED | rc=0 >>
host455
10.20.16.456 | CHANGED | rc=0 >>
host456
10.1.226.457 | CHANGED | rc=0 >>
host457
```

远程执行命令，没有提示输入密码，安全起见，**此时可以将`hosts`文件中的`ansible_ssh_pass` 参数删除**。

#### AntDB的使用场景

##### 用户相关

用户相关的操作主要使用的ansible的`user` 模块，详细参数参考：https://docs.ansible.com/ansible/latest/modules/user_module.html.

通过 `ansible-doc user` 可以查看该模块的帮助信息。

###### 创建用户

用户相关创建和查看的场景，建议使用一个playbook来完成。playbook就是一组ad-hoc的集合。

```yaml
vi antdb_create_user.yaml
- name: antdb_create_user
  hosts: all
  remote_user: root
  gather_facts: false
  
  tasks:
  - name: create user
    user: name="{{ user }}"  generate_ssh_key=yes
    tags:
    - adduser    
  - name: cat user
    command: id "{{ user }}"
    tags:
    - catuser 
  - name: change user password
    user: name="{{ user }}" password="{{ password | password_hash('sha512') }}"
    tags:
    - changepasswd     
  - name: cat  group
    shell: cat /etc/group|grep  -w "{{ group }}"
    tags:
    - catgroup 
  - name: add user to sudoers 
    lineinfile:
      dest: /etc/sudoers
      insertafter: "^# %wheel        ALL=(ALL)       NOPASSWD: ALL"
      line: "{{ user }}        ALL=(ALL)       NOPASSWD: ALL"
      validate: 'visudo -cf %s'
    tags:
    - addsudo 
```

> `{{ user }} ` 的变量表示是从外部执行的时候接受参数传值。

查看playbook中包含哪些任务：

```shell
[root@intel175 ansible]# ansible-playbook antdb_create_user.yaml --list-tasks

playbook: antdb_create_user.yaml

  play #1 (all): antdb_create_user      TAGS: []
    tasks:
      create user       TAGS: [adduser]
      cat user  TAGS: [catuser]
      change user password      TAGS: [changepasswd]
      cat  group        TAGS: [catgroup]
      add user to sudoers       TAGS: [addsudo]
```

执行playbook：

> `--extra-vars` 指定参数给yaml文件中的变量赋值。

```shell
ansible-playbook -i hosts antdb_create_user.yaml --extra-vars "user=antdbtestdang group=antdbtestdang  password=123"


[root@intel175 ansible]# ansible-playbook -i hosts antdb_create_user.yaml --extra-vars "user=antdbtestdang group=antdbtestdang  password=123"

PLAY [antdb_create_user] ****************************************************************************************************************************************

TASK [create user] **********************************************************************************************************************************************
changed: [10.20.16.455]
changed: [10.20.16.456]
changed: [10.1.226.457]

TASK [cat user] *************************************************************************************************************************************************
changed: [10.20.16.455]
changed: [10.20.16.456]
changed: [10.1.226.457]

TASK [change user password] *************************************************************************************************************************************
 [WARNING]: The input password appears not to have been hashed. The 'password' argument must be encrypted for this module to work properly.
changed: [10.20.16.455]
changed: [10.20.16.456]
changed: [10.1.226.457]

TASK [cat  group] ***********************************************************************************************************************************************
changed: [10.20.16.455]
changed: [10.20.16.456]
changed: [10.1.226.457]

TASK [add user to sudoers] **************************************************************************************************************************************
changed: [10.20.16.455]
changed: [10.20.16.456]
changed: [10.1.226.457]

PLAY RECAP ******************************************************************************************************************************************************
10.20.16.455               : ok=5    changed=5    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
10.21.20.456               : ok=5    changed=5    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
10.21.20.457               : ok=5    changed=5    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   

[root@intel175 ansible]# 
```

修改用户密码的步骤报错，通过`123`的密码并不能登录到新创建的用户：

```
[root@intel175 ansible]# ssh antdbtestdang@10.21.20.345
antdbtestdang@10.21.20.345's password: 
Permission denied, please try again.
```

单个task失败后，可以通过playbook的 `--tags`参数执行指定的task:

```shell
ansible-playbook -i hosts antdb_create_user.yaml --tags "changepasswd" --extra-vars "user=antdbtestdang password=123"

[root@intel175 ansible]# ansible-playbook -i hosts antdb_create_user.yaml --tags "changepasswd" --extra-vars "user=antdbtestdang password=123"

PLAY [antdb_create_user] ****************************************************************************************************************************************

TASK [change user password] *************************************************************************************************************************************
changed: [10.20.16.12]
changed: [10.20.16.12]
changed: [10.20.16.13]

PLAY RECAP ******************************************************************************************************************************************************
10.1.226.11               : ok=1    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
10.21.20.12               : ok=1    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
10.21.20.13               : ok=1    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0 
```

执行成功，再次使用`123`密码登录：

```shell
[root@intel175 ansible]# ssh antdbtestdang@10.21.20.345
antdbtestdang@10.21.20.345's password: 
Last failed login: Wed Jul 24 15:38:44 CST 2019 from intel175 on ssh:notty
There was 1 failed login attempt since the last successful login.
[antdbtestdang@intel175 ~]$ 
```

###### antdb用户设置ssh免密

主控主机的antdb用户到集群其他主机的ssh免密设置。

```
ansible all -m authorized_key -a "user=antdbtestdang key='{{ lookup('file', '/home/antdbtestdang/.ssh/id_rsa.pub') }}' exclusive=yes manage_dir=no" -k
```

> 修改为现场使用的用户名

###### 设置profile（待测试）

`user` 模块提供 `profile`选型，可以设置用户的profile信息。示例如下：

```
ansible 10.21.20.345 -m user -a "user=antdbtestdang profile='export ADB_HOME=/opt/app/antdb' "
```



###### 删除用户

删除等高危操作，建议使用ad-hoc的方式去操作。

```
ansible all -m user -a "user=antdbtestdang state=absent remove=yes"
```

查看是否删除：

```shell
[root@intel175 ansible]# ansible all -m shell -a "id antdbtestdang"
10.20.16.11 | FAILED | rc=1 >>
id: antdbtestdang: no such usernon-zero return code
10.20.16.12 | FAILED | rc=1 >>
10.20.16.13 | FAILED | rc=1 >>
id: antdbtestdang: no such usernon-zero return code
10.20.16.14 | FAILED | rc=1 >>
id: antdbtestdang: no such usernon-zero return code
10.1.226.14 | FAILED | rc=1 >>
id: antdbtestdang: No such usernon-zero return code
[root@intel175 ansible]# 
```

已经删除完成。

##### 复制文件

将一台主机上的文件或者文件夹复制到所有主机上。使用自带的`copy`模块，查看帮助：`ansible-doc copy`

-  copy oracle 文件夹

   ```
   cd ~
   ansible all -m copy -a "src=oracle/ dest=oracle/  local_follow=false"
   # src和dest可以是绝对路径，也可以是相对路径。
   ```
>软链接到目标端会成为实际的文件，添加local_follow 选项可保持原样。

- copy `.bashrc`

  ```
ansible all -m copy -a "src=.bashrc dest=.bashrc "
  ```


##### 创建文件、文件夹

使用ansible的`file`模块

```shell
# 创建文件夹
ansible all -m file -a "path=~/app state=directory" 
# 删除文件夹
ansible all -m file -a "path=~/app state=directory" 
# 如果要一次创建多个文件夹，需要使用playbook：
- name: Make sure the sites-available, sites-enabled and conf.d directories exist
  file:
    path: "{{nginx_dir}}/{{item}}"
    owner: root
    group: root
    mode: 0755
    recurse: yes
    state: directory
  with_items: ["sites-available", "sites-enabled", "conf.d"]
```

##### yum 操作

使用ansible的`yum`模块。

```shell
# 安装软件
ansible all -m yum -a "name=lrzsz state=present" 
# 卸载软件
ansible all -m yum -a "name=lrzsz state=absent" 
# 查看软件是否安装,没有的话会尝试安装。
ansible all -m yum -a "name=lrzsz state=installed" 
```

#####  批量执行shell命令

使用ansible的`shell`模块。

```shell
# 查看系统时间和主机名称
ansible all -m shell -a "date&&hostname"
```



#### 参考链接

- https://ansible-tran.readthedocs.io/en/latest/docs/intro_inventory.html#inventoryformat
- https://github.com/ansible/ansible/issues/23902 