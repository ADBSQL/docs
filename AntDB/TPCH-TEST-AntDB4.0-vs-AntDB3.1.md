
本文通过TPCH模型，验证AntDB在大版本迭代过程中，22种场景下的性能指标提升对比测试。
## 环境介绍

|操作系统|centos7.4|
|:---|:------|
|内存|128GB|
|磁盘|SSD|
|AntDB版本|3.1 vs 4.0|
|AntDB架构|2C2D|

## 测试方法
1. 每次测试前，清空内存的缓存数据，让数据重新加载，防止缓存数据对测试结果的干扰。
2. 进行TPCH测试。 

    TPCH测试步骤，不在本文探讨范围。想了解详细测试步骤，请参考  [TPC-H benchmark](https://github.com/digoal/gp_tpch)

## 测试结果

|单位: s	|AntDB3.1@20181130	|AntDB4.0@20181210|
|:----|:-----|:-------|
|query_1	|13	|10|
|query_2	|2	|2 |
|query_3	|40	|34|
|query_4	|1	|1 |
|query_5	|67	|26|
|query_6	|2	|2 |
|query_7	|9	|13|
|query_8	|3	|4 |
|query_9	|27	|22|
|query_10	|5	|5 |
|query_11	|1	|2 |
|query_12	|9	|9 |
|query_13	|92	|91|
|query_14	|53	|4 |
|query_15	|6	|7 |
|query_16	|11	|11|
|query_17	|40	|45|
|query_18	|24	|17|
|query_19	|1	|1 |
|query_20	|58	|39|
|query_21	|226	|97|
|query_22	|20	|24|

## 结果分析
**TPCH query22 各指标对比**
![TPCH query22 各指标对比](https://github.com/greatebee/AntDB/blob/master/pic/tpch_1.png)
**总耗时对比**
![总耗时对比](https://github.com/greatebee/AntDB/blob/master/pic/tpch_2.png)
**性能提升对比**
![性能提升对比](https://github.com/greatebee/AntDB/blob/master/pic/tpch_3.png)

## 总结
1. AntDB最新版本4.0 得益于在数据reduce、执行计划微调等方面的改善，query 5、14、21 3种场景性能提升较为显著。

    AntDB4.0最新版本相对AntDB3.1版本 性能整体又提升了 34% 。
2. 当前测试环境datanode节点数较少，继续增加节点数可以进一步提升性能。感兴趣的同学，可以搭建更多数据节点进行使用和验证。
3. TPCH模型更适用于关系型数据库，因此在分布式数据库，TPCH模型无法充分展现 MPP 并行计算的能力，对测试结果有一定负影响。

## 参考
AntDB QQ群号：496464280

[AntDB github链接](https://github.com/ADBSQL)
