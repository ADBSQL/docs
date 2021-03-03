Oracle语法兼容对比 Oracle vs AntDB vs Postgresql
## 1. DDL
create，alter，drop，truncate
## 2. DML
insert，update，delete
## 3. DQL
select
## 4. DCL
grant，revoke，alter password
## 5. TCL
commit，rollback，savepoint
## 6. 数据类型

|ORACLE	|AntDB	|Postgresql|
|:------|:------|:---------|
|varchar2	|varchar2	|varchar|
|char(n)	|char(n)	|char(n)|
|date（日期）	|date（日期）	|timestamp（时间日期型）、date（日期）、time（时间）|
|number(n)	|number(n)	|smallint、int、bigint|
|number(p,n)	|number(p,n)	|numeric(p,n)（低效）、float（高效）|
|clob	|clob	|text    |
|blob	|blob	|bytea   |
|rownum	|rownum	|无  |
|rowid	|rowid	|ctid|

## 7. 系统函数
**原生支持： 原生支持： √；不支持：╳；扩展支持 扩展支持 ：○**

|函数类型	|函数名称	|ORACLE	|AntDB	|Postgresql|
|:--------|:----------|:----------|:-------|:-----------|
|数值函数	|ABS 	|√ 	|√ 	|√ |
|	        |ACOS 	|√ 	|√ 	|√ |
|	        |ASIN 	|√ 	|√ 	|√ |
|	        |ATAN 	|√ 	|√ 	|√ |
|	        |ATAN2 	|√ 	|√ 	|√ |
|	        |BITAND 	|√ 	|√ 	|√ |
|	        |CEIL 	|√ 	|√ 	|√ |
|	        |COS 	|√ 	|√ 	|√ |
|	        |COSH 	|√ 	|√ 	|√ |
|	        |EXP 	|√ 	|√ 	|√ |
|	        |FLOOR 	|√ 	|√ 	|√ |
|	        |LN 	|√ 	|√ 	|√ |
|	        |LOG 	|√ 	|√ 	|√ |
|	        |MOD 	|√ 	|√ 	|√ |
|	        |NANVL 	|√ 	|√ 	|○ |
|	        |POWER 	|√ 	|√ 	|√ |
|	        |ROUND (number) 	|√ 	|√ 	|√ |
|	        |SIGN 	|√ 	|√ 	|√ |
|	        |SIN 	|√ 	|√ 	|√ |
|	        |SINH 	|√ 	|√	|○ |
|	        |SQRT 	|√ 	|√ 	|√ |
|	        |TAN 	|√ 	|√ 	|√ |
|	        |TANH 	|√ 	|√	|○ |
|	        |TRUNC (number) 	|√ 	|√ 	|√ |
|字符函数	|CHR 	|√ 	|√ 	|√ |
|	        |CONCAT 	|√ 	|√ 	|√ |
|	        |INITCAP 	|√ 	|√ 	|√ |
|	        |LOWER 	|√ 	|√ 	|√ |
|	        |LPAD 	|√ 	|√ 	|√ |
|	        |LTRIM 	|√ 	|√ 	|√ |
|	        |REGEXP_REPLACE 	|√ 	|√ 	|√ |
|	        |REGEXP_SUBSTR 	|√ 	|√ 	|╳ |
|	        |REPLACE 	|√ 	|√ 	|√ |
|	        |RPAD 	|√ 	|√ 	|√ |
|	        |RTRIM 	|√ 	|√ 	|√ |
|	        |SUBSTR 	|√ 	|√ 	|√ |
|	        |TRANSLATE 	|√ 	|√ 	|√ |
|	        |TREAT 	|√ 	|╳ 	|╳ |
|	        |TRIM 	|√ 	|√ 	|√ |
|	        |UPPER 	|√ 	|√ 	|√ |
|	        |ASCII 	|√ 	|√ 	|√ |
|	        |INSTR 	|√ 	|√ 	|○ |
|	        |LENGTH 	|√ 	|√ 	|√ |
|	        |REGEXP_INSTR 	|√ 	|√ 	|╳ |
|	        |REVERSE 	|√ 	|√ 	|√ |
|日期函数	|ADD_MONTHS 	|√ 	|√	|○ |
|	        |CURRENT_DATE 	|√ 	|√ 	|√ |
|	        |CURRENT_TIMESTAMP 	|√ 	|√ 	|√ |
|	        |EXTRACT (datetime) 	|√ 	|√ 	|√ |
|	        |LAST_DAY 	|√ 	|√ 	|○ |
|	        |LOCALTIMESTAMP 	|√ 	|╳ 关键字|	╳ 关键字|
|	        |MONTHS_BETWEEN 	|√ 	|√ 	|○ |
|	        |NEW_TIME 	|√ 	|√ 	|╳ |
|	        |NEXT_DAY 	|√ 	|√ 	|○ |
|	        |ROUND (date) 	|√ 	|√ 	|╳ |
|	        |SYSDATE 	|√ 	|√ |	╳ |
|	        |SYSTIMESTAMP 	|√ 	|√ 	|╳ |
|	        |TO_CHAR (datetime) 	|√ 	|√ 	|√ |
|	        |TO_TIMESTAMP 	|√ 	|√ 	|√ |
|	        |TRUNC (date) 	|√ 	|√ 	|√ |
|编码解码函数	|DECODE 	|√ 	|√ 	|○ |
|	            |DUMP 	|√ 	|√ 	|○ |
|空值比较函数	|COALESCE 	|√ 	|√ 	|√ |
|	            |LNNVL 	|√ 	|√ 	|○ |
|	            |NANVL 	|√ 	|√ 	|○ |
|	            |NULLIF 	|√ 	|√ 	|√ |
|	            |NVL 	|√ 	|√ 	|○ |
|	            |NVL2 	|√ 	|√ 	|○ |
|通用数值比较函数	|GREATEST 	|√ 	|√ 	|√ |
|	                |LEAST 	|√ 	|√ 	|√ |
|类型转换函数	|CAST 	              |√ 	|√ 	|√ |
|	            |CONVERT 	            |√ 	|√ 	|○ |
|	            |TO_CHAR (character) 	|√ 	|√ 	|√ |
|	            |TO_CHAR (datetime) 	|√ 	|√ 	|√ |
|	            |TO_CHAR (number) 	  |√ 	|√ 	|√ |
|	            |TO_DATE 	            |√ 	|√ 	|√ |
|	            |TO_NUMBER 	          |√ 	|√ 	|√ |
|	            |TO_TIMESTAMP 	      |√ 	|√ 	|√ |
|分析函数	|AVG * 	        |√ 	|√ 	|√ |
|	        |COUNT * 	      |√ 	|√ 	|√ |
|	        |DENSE_RANK 	  |√ 	|√ 	|√ |
|	        |FIRST 	        |√ 	|╳ 	|╳ |
|	        |FIRST_VALUE * 	|√ 	|√ 	|√ |
|	        |LAG 	          |√ 	|√ 	|√ |
|	        |LAST 	        |√ 	|╳ 	|╳ |
|	        |LAST_VALUE * 	|√ 	|√ 	|√ |
|	        |LEAD 	        |√ 	|√ 	|√ |
|	        |MAX * 	        |√ 	|√ 	|√ |
|	        |MIN * 	        |√ 	|√ 	|√ |
|	        |RANK 	        |√ 	|√ 	|√ |
|	        |ROW_NUMBER 	  |√ 	|√ 	|√ |
|	        |SUM * 	        |√ 	|√ 	|√ |

## 8. SQL运算符

|SQL运算符类型	|运算符名称	|ORACLE	|AntDB	|Postgresql|
|:--------|:----------|:----------|:-------|:-----------|
|算数运算符	|+	|√ 	|√ 	|√ |
|	          |-	|√ 	|√ 	|√ |
|	          |*	|√ 	|√ 	|√ |
|	          |/	|√ 	|√ 	|√ |
|逻辑运算符	|and	|√ 	|√ 	|√ |
|	          | or	|√ 	|√ 	|√ |
|	          |not	|√ 	|√ 	|√ |
|比较运算符	|!=	|√ 	|√ 	|√ |
|	          |<>	|√ 	|√ 	|√ |
|	          |^=	|√ 	|╳ 	|╳ |
|	          |=	|√ 	|√ 	|√ |
|	          |<	|√ 	|√ 	|√ |
|	          |>	|√ 	|√ 	|√ |
|	          |<=	|√ 	|√ 	|√ |
|	          |>=	|√ 	|√ 	|√ |
|	          |is (not) null	    |√ 	|√ 	|√ |
|	          |(not) between and	|√ 	|√ 	|√ |
|	          |(not)in	|√ 	|√ 	|√ |
|	          |all/any	|√ 	|√ 	|√ |
|	          |exists	  |√ 	|√ 	|√ |
|	          |like	    |√ 	|√ 	|√ |
|连接运算符	| ll	|√ 	|√ 	|√ |
|合并运算符	|union (all)	  |√ 	|√ 	|√ |
|	          |    minus	    |√ 	|√ 	|except |
|	          |    intersect	|√ 	|╳ 	|√ |


## 9. 查询

|SQL查询类型	|名称	|ORACLE	|AntDB	|Postgresql|
|:--------|:----------|:----------|:-------|:-----------|
|去重	|distinct	|√ 	|√ 	|√ |
|	    |  unique	|√ 	|╳	|╳   |
|分组	|group by	|√ 	|√ 	|√ |
|过滤	|having	  |√ 	|√ 	|√ |
|排序	|order by	|√ 	|√ 	|√ |
|递归	|connect by	  |√ 	|√ 	|╳ |
|cte	|cte	        |√ 	|√ 	|√ |
|case when	|case when	      |√ 	|√ 	|√ |
|批量insert	|insert all into	|√ 	|╳ insert into values	|╳ insert into values|
|merge into	|merge into	      |√ 	|╳ upsert	|╳ upsert|


## 10. 表连接

|表连接类型	|表连接名称	|ORACLE	|AntDB	|Postgresql|
|:--------|:----------|:----------|:-------|:-----------|
|内连接	|(inner) join	        |√ 	|√ 	|√ |
|	      |from tableA,tableB	  |√ 	|√ 	|√ |
|左连接	|left (outer) join	  |√ 	|√ 	|√ |
|右连接	|right (outer) join	  |√ 	|√ 	|√ |
|全连接	|full (outer) join	  |√ 	|√ 	|√ |
|(+)	  |(+)	                |√ 	|√ 	|╳ |


## 11. 视图/函数/存储过程/触发器

|类型	|名称	|ORACLE	|AntDB	|Postgresql|
|:--------|:----------|:----------|:-------|:-----------|
|视图	    |create view	    |√ 	|√ 	|√ |
|	        |alter view	      |√ 	|√ 	|√ |
|	        |drop view	      |√ 	|√ 	|√ |
|函数	    |create fuction	  |√ 	|√ 	|√ |
|	        |alter fuction	  |√ 	|√ 	|√ |
|	        |drop fuction	    |√ 	|√ 	|√ |
|存储过程	|create procedure	|√ 	|√ 	|√ |
|	        |alter procedure	|√ 	|√ 	|√ |
|	        |drop procedure	  |√ 	|√ 	|√ |
|触发器	  |create trigger	  |√ 	|√ 	|√ |
|	        |alter trigger	  |√ 	|√ 	|√ |
|	        |drop trigger	    |√ 	|√ 	|√ |


## 12. sequence

|类型	|名称	|ORACLE	|AntDB	|Postgresql|
|:--------|:----------|:----------|:-------|:-----------|
|新建序列	|create sequence	|√ 	|√ 	|√ |
|修改序列	|alter sequence	  |√ 	|√ 	|√ |
|删除序列	|drop sequence	  |√ 	|√ 	|√ |
|操作序列	|seq.nextVal	    |√ 	|√ 	|╳ nextVal('seq')|
|	        |seq.currVal	    |√ 	|√ 	|╳ currVal('seq')|


## 13. 其他

|类型	|名称	|ORACLE	|AntDB	|Postgresql|
|:--------|:----------|:----------|:-------|:-----------|
|过程语言	        |declare	    |√ 	|√ 	|√ |
|	                |exception	  |√ 	|√ 	|√ |
|	                |cursor	    |√ 	|√ 	|√ |
|自定义type	      |create type	|√ 	|√ 	|√ |
|	                |alter type	|√ 	|√ 	|√ |
|	                |drop type	  |√ 	|√ 	|√ |
|数据类型隐式转换	|隐式转换	  |√ 	|√ 	|╳ |
|oracle别名	      |oracle别名	|√ 	|√ 	|╳ |
|类型复制	        |%type	      |√ 	|√ 	|√ |
|	                |%rowtype	  |√ 	|√ 	|√ |
|like通配符	      |%	          |√ 	|√ 	|√ |
|	                |_	          |√ 	|√ 	|√ |
|dual虚拟表	      |dual	      |√ 	|√ 	|╳ |


