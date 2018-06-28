# AntDB�����������ʹ��˵��

## ʹ�ó���
�ܶ�ֲ�ʽ�����£�һ����Ƭ�ֶβ������������еĳ�����

������ʷҵ���˵����û�ID����Ƭ���ʺ����û�ͳ�ƣ�������һЩ�����Ҫ�������Ų�ѯ�����������Ϊ���ҵ�һ��������Ӧ�ļ�¼����Ϊ��֪������¼���ĸ��ڵ��ϣ���������Ҫȫ�ڵ�ɨ�衣������޷����ֲַ�ʽ���ŵ㣬�����Դ�˷ѣ���Ч�����ڵ�ֻ��һ�������ر����ڸ߲���ʱ���ͺܿ��ܻ����CPU�����á�

�������������AntDB�ĸ�������������Ч��Ӧ�ԡ�
### ԭ��Ϊ
�����б�t1(a,b,c,...)��aΪ��Ƭ��,bΪ���泡���еġ��������С�
1. ��ԷǷ�Ƭ��b����һ�Ÿ�������������������ķ�Ƭ��Ϊb���ͷǷ�Ƭ�ֶ�a�����е����ݶ�������t1����ͬ����
2. �����ѯt1��ʱ�����Ĺ����������С�b=xxx�������ı��ʽ�����xxx���뵽�Ծ͵ĸ����������У���ѯ����a��ֵ���ڵĽڵ㡣
3. �޸�ִ�мƻ���ֻ����һ�����ҳ��Ľڵ���ִ�в�ѯ��

���յ�ִ��ʱ������������
* һ�����������Ҫȫ�ڵ�ɨ��Ĳ�ѯ������ֻ��Ҫ�������ڵ���ɨ�衣���β�ѯʱ��䳤���߲�����ѯʱ���̡�
* ����������ڶ�����ѯ�����������������ݣ�����Ҫ��ɨ���������β�ѯʱ�䲻�䣬�߲�����ѯʱ���̡�
* �������ڶ����鵽�����������нڵ��ϣ�����Ҫȫ�ڵ�ɨ���������β�ѯʱ��䳤���߲�����ѯʱ��䳤��

���Դ�������������ʹ���������ͬ��Ҫ����Щ�ظ��ʵ͵��С��������շ�����ʹ��ѯʱ��䳤��

��Ϊ�и����Ĵ��ڣ��������ݵĸ��²������ĸ������������ݸ���ʱ��ͬ�����¸�������
## ����
### ��������
```sql
create table test(id int, name text, age int) distribute by hash(id);
```
### �� _name_ �ϴ�����������
```sql
create auxiliary table on test(name);
\d+ test
```
```
                         Table "public.test"
 Column |  Type   | Modifiers | Storage  | Stats target | Description 
--------+---------+-----------+----------+--------------+-------------
 id     | integer |           | plain    |              | 
 name   | text    |           | extended |              | 
 age    | integer |           | plain    |              | 
Auxiliary table:
    "test_name_aux" on test(name)
Distribute By: HASH(id)
Location Nodes: ALL DATANODES
```
### ������test�ϲ���һЩ����
```sql
insert into test select n,'name'||n,random()*100 from generate_series(1,10) as n;
select *,adb_node_oid() as node from test;
```
```
 id |  name  | age | node  
----+--------+-----+-------
 14 | name14 |  12 | 16385
 15 | name15 |  46 | 16385
 20 | name20 |  46 | 16385
 11 | name11 |  81 | 16386
 12 | name12 |   9 | 16386
 17 | name17 |  15 | 16386
 18 | name18 |  37 | 16386
 19 | name19 |  98 | 16386
 10 | name10 |   3 | 16387
 13 | name13 |  25 | 16387
 16 | name16 |  73 | 16387
(11 rows)
```
### �Ƿ�Ƭ�ֶε�ִֵ�мƻ�
```sql
--��ѯ���
select * from test where name='name12';
 id |  name  | age 
----+--------+-----
 12 | name12 |   9
(1 row)

--ִ�мƻ���nameΪ�Ƿ�Ƭ�ֶ�,����ִ�мƻ�ֻ��16386����ڵ���ִ��
explain (verbose,analyze,costs off,timing off) select * from test where name='name12';
                      QUERY PLAN                       
-------------------------------------------------------
 Cluster Gather (actual rows=1 loops=1)
   Remote node: 16386
   ->  Seq Scan on public.test (actual rows=0 loops=1)
         Output: id, name, age
         Filter: (test.name = 'name12'::text)
         Remote node: 16386
         Node 16386: (actual rows=1 loops=1)
 Planning time: 15.222 ms
 Execution time: 0.433 ms
(9 rows)

--�ر�ʹ�ø������ܺ��ִ�мƻ�
set use_aux_types =off;
explain (verbose,analyze,costs off,timing off) select * from test where name='name12';
                      QUERY PLAN                       
-------------------------------------------------------
 Cluster Gather (actual rows=1 loops=1)
   Remote node: 16385,16386,16387
   ->  Seq Scan on public.test (actual rows=0 loops=1)
         Output: id, name, age
         Filter: (test.name = 'name12'::text)
         Remote node: 16385,16386,16387
         Node 16385: (actual rows=0 loops=1)
         Node 16386: (actual rows=1 loops=1)
         Node 16387: (actual rows=0 loops=1)
 Planning time: 0.331 ms
 Execution time: 1.743 ms
(11 rows)

--��in���ʽͬ��֧��,������¼��ͬһ���ڵ���
set use_aux_types =on;
explain (verbose,analyze,costs off,timing off) select * from test where name in('name12','name17');
                          QUERY PLAN                           
---------------------------------------------------------------
 Cluster Gather (actual rows=2 loops=1)
   Remote node: 16386
   ->  Seq Scan on public.test (actual rows=0 loops=1)
         Output: id, name, age
         Filter: (test.name = ANY ('{name12,name17}'::text[]))
         Remote node: 16386
         Node 16386: (actual rows=2 loops=1)
 Planning time: 204.687 ms
 Execution time: 0.365 ms
(9 rows)

--������¼��������ͬ�ڵ���
explain (verbose,analyze,costs off,timing off) select * from test where name in('name12','name16');
                          QUERY PLAN                           
---------------------------------------------------------------
 Cluster Gather (actual rows=2 loops=1)
   Remote node: 16386,16387
   ->  Seq Scan on public.test (actual rows=0 loops=1)
         Output: id, name, age
         Filter: (test.name = ANY ('{name12,name16}'::text[]))
         Remote node: 16386,16387
         Node 16386: (actual rows=1 loops=1)
         Node 16387: (actual rows=1 loops=1)
 Planning time: 104.125 ms
 Execution time: 0.409 ms
(10 rows)
```

## ����������������﷨Ϊ
CREATE AUXILIARY TABLE [*aux_name*] ON *table_name*(*column*);