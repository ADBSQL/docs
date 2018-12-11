# AntDB用户授权
## AntDB权限说明
AntDB权限分为两部分，一部分是数据库系统权限，可以授予role或user(两者区别在于后者默认具有login权限)；一部分为数据库对象的操作权限。
对超级用户不做权限检查，其它走acl。



- 数据库系统权限pg_roles
		
rolsuper		是否具有超级用户权限

rolinherit		是否可以继承其他角色的权限

rolcreaterole	是否可以创建更多角色

rolcreatedb		是否可以创建数据库

rolcanlogin		是否可以登录

rolreplication	是否可以进行流复制

rolconnlimit	该角色可以连接的次数，如果没有限制，为-1

rolpassword		口令

rolvaliduntil	口令失效日期（只用于口令认证）；如果没有失效期，为 NULL 

- 数据库对象的操作权限pg_class.relacl
 
r -- SELECT ("读")

w -- UPDATE ("写")

a -- INSERT ("追加")

d -- DELETE

D -- TRUNCATE

x -- REFERENCES

t -- TRIGGER

X -- EXECUTE

U -- USAGE

C -- CREATE

c -- CONNECT

T -- TEMPORARY

arwdDxt -- ALL PRIVILEGES (针对表，对于其他对象该权限列表会变化)

操作权限说明：

SELECT：该权限用来查询表或是表上的某些列，或是视图，序列。

INSERT：该权限允许对表或是视图进行插入数据操作，也可以使用COPY FROM进行数据的插入。

UPDATE：该权限允许对表或是或是表上特定的列或是视图进行更新操作。

DELETE：该权限允许对表或是视图进行删除数据的操作。

TRUNCATE：允许对表进行清空操作。

REFERENCES：允许给参照列和被参照列上创建外键约束。

TRIGGER：允许在表上创建触发器。

CREATE：对于数据库，允许在数据库上创建Schema；对于Schema，允许对Schema上创建数据库对象；对于表空间，允许把表或是索引指定到对应的表空间上。

CONNECT：允许用户连接到指定的数据库上。

TEMPORARY或是TEMP：允许在指定数据库的时候创建临时表。

EXECUTE：允许执行某个函数。

USAGE：对于程序语言来说，允许使用指定的程序语言创建函数；对于Schema来说，允许查找该Schema下的对象；对于序列来说，允许使用currval和nextval函数；对于外部封装器来说，允许使用外部封装器来创建外部服务器；对于外部服务器来说，允许创建外部表。

ALL PRIVILEGES：表示一次性给予可以授予的权限。

## 用例
### 新建只读角色

CREATE ROLE role1_select WITH

	LOGIN
	NOSUPERUSER
	CREATEDB
	CREATEROLE
	INHERIT
	REPLICATION
	CONNECTION LIMIT 10
	VALID UNTIL '2018-12-31T17:01:15+08:00' 
	PASSWORD '123456';
COMMENT ON ROLE role1_select IS 'for read';

grant SELECT on table t1 to role1_select;
### 新建写角色
CREATE ROLE role1_insert WITH

	LOGIN
	NOSUPERUSER
	CREATEDB
	CREATEROLE
	INHERIT
	REPLICATION
	CONNECTION LIMIT 10
	VALID UNTIL '2018-12-31T17:01:15+08:00' 
	PASSWORD '123456';
COMMENT ON ROLE role1_insert IS 'for write';

grant INSERT,UPDATE,DELETE,TRUNCATE on table t1 to role1_insert;
### 新建用户并赋予指定角色
创建一个默认用户，只有login权限，其他权限都收回。

CREATE USER user1 WITH

	LOGIN
	NOSUPERUSER
	NOCREATEDB
	NOCREATEROLE
	INHERIT
	NOREPLICATION
	CONNECTION LIMIT -1
	PASSWORD 'xxxxxx';
#### 赋予只读角色
grant role1_select TO user1 ;
#### 赋予写角色
grant role1_insert TO user1 ;
### 可以通过函数来验证模式下的表的相应权限
select has_table_privilege('aa','select');

select has_table_privilege('aa','insert');


## 对sequence类型的授权
usage有currval,nextval这两个函数可用

grant usage on sequence sq1 to user1;

update有setval这个函数可用

grant update on sequence sq1 to user1;


## 角色权限的继承

CREATE ROLE role_father xxx;

CREATE ROLE role_son xxx;

grant role_father to role_son;

## 查看权限
在psql中的查看权限的快捷指令

\dn[S+]		列出所有模式

\dp			列出表，视图和序列的访问权限，同\z

\du[S+]		列出角色

\ddp		列出默认权限


database、schema、table_seq_view_etc、table_column 分4个级别来授权。
