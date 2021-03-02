
create or replace language plpythonu;

-- =============================================================================
-- Core 堆栈信息类型，用于函数返回值
-- =============================================================================
DROP TYPE if exists type_core_stack cascade;
CREATE TYPE type_core_stack
AS ( node_name               text
   , file_name               text
   , modify_time             timestamp
   , stack_id                int
   , stack_data              text
   , function_name           text
   , function_params         text
   , code_file               text
   , code_position           text
   );


-- =============================================================================
-- pg_query_corestack_local
-- ====================
-- 【作用】 当前节点的 Core 文件查看与解析函数
-- 【参数】 1. 开始时间
--         2. 结束时间
--         3. 并行度
--         4. 是否打印 notice 信息
-- 【逻辑】 通过 echo bt | gdb postgres <core_file> 的方式查看 Core 文件的堆栈信息
-- 【返回】 Core 堆栈信息表（字段参考 type_core_stack 类型）
-- =============================================================================
drop function if exists pg_query_corestack_local (pi_begin timestamp, pi_end timestamp, pi_parallel int, pi_notice bool, pi_node text);
create or replace function pg_query_corestack_local ( pi_begin     timestamp  Default clock_timestamp() - interval '1 month'
                                                       , pi_end       timestamp  Default clock_timestamp()
                                                       , pi_parallel  int        Default 8
                                                       , pi_notice    bool       Default 'false'
                                                       , pi_node      text       Default 'CURRENT')
returns setof type_core_stack
as $$
import os
import re
import glob
import subprocess
from multiprocessing import Process,Queue
q_core_stack = Queue(10000)
p_list = []

# 获取 Core 文件目录
# --------------------------------------------------------------------------
# 1. 从内核参数中获取
#    [hongye@localhost ~]$ sysctl -a 2>/dev/null | grep 'kernel.core_pattern' | tail -1
#    kernel.core_pattern = /data/coredump/core-%e-%p-%t
# 2. 从数据库目录中获取
#    postgres=# select setting from pg_settings where name = 'data_directory';
#                  setting
#    -----------------------------------
#     /data/hongye/data_5.0/alone_ZJCMC
core_dirs = []
res = subprocess.Popen("/usr/sbin/sysctl -a | grep 'kernel.core_pattern'", shell=True, stdout=subprocess.PIPE).stdout.read().strip()
if res:
    core_dirs.append('/' + '/'.join(res.split('/')[1:-1]))
    if pi_notice:
        plpy.notice('[{}] Get core directory from kernel: {}'.format(pi_node, core_dirs[-1]))

res = plpy.execute("select setting from pg_settings where name = 'data_directory'")
core_dirs.append(res[0]['setting'])
if pi_notice:
    plpy.notice('[{}] Get default core directory: {}'.format(pi_node, core_dirs[-1]))

# Core 文件堆栈解析函数
# --------------------------------------------------------------------------
def parse_core(core_file, mtime):
    res = subprocess.Popen("echo bt | gdb postgres {}".format(core_file), shell=True, stdout=subprocess.PIPE).stdout.read().strip()
    res_list = res.split('(gdb)')
    # 原始 stack 数据， ID = -1
    q_core_stack.put([pi_node, core_file, mtime, -1, res, None, None, None, None])
    # 解析后的 stack 数据， ID >= 0
    if len(res_list) == 3 and res_list[1].strip():
        # 按照 stack id 拆分，形成 [id, stack, id stack ...] 的列表
        stack_lines = re.split(r'#(\d+)\s+0x\w+\s+in\s+', res_list[1])
        for (stack_id, stack_data) in zip(stack_lines[1::2], stack_lines[2::2]):
            # 拆分函数与代码文件
            data_list = re.split(r'\s+(?:from|at)\s+', stack_data.strip())
            if len(data_list) == 1:
                data_list.append('')
            # 拆分函数与参数
            func_list = re.split(r'\s+\(', data_list[0], 1)
            if len(func_list) == 1:
                func_list.append('')
            # 拆分代码文件与行号
            code_list = re.split(r':', data_list[1])
            if len(code_list) == 1:
                code_list.append('')
            q_core_stack.put([pi_node, core_file, mtime, stack_id, None, func_list[0], '({}'.format(func_list[1]), code_list[0], code_list[1]])

# 多进程调用 Core 解析函数
# --------------------------------------------------------------------------
for l_path in core_dirs:
    for l_file in glob.glob(l_path + '/*'):
        f_stat = (plpy.execute("select size, modification as mtime, not isdir as isfile from pg_stat_file('{}')".format(l_file)))[0]
        if f_stat['isfile'] and f_stat['mtime'] >= pi_begin and f_stat['mtime'] <= pi_end and re.search('core', l_file, flags=re.I) and f_stat['size'] > 1048576:
            if pi_notice:
                plpy.notice('[{}] Get core file [{}]\t[{}]\t[{}]'.format(pi_node, l_file, f_stat['mtime'], f_stat['size']))
            while len(p_list) >= pi_parallel:
                while not q_core_stack.empty():
                    core_item = q_core_stack.get()
                    yield (core_item)
                for p in p_list:
                    p.join(0.01)
                p_list = [x for x in p_list if x.is_alive()]
            p = Process(target=parse_core, args=(l_file, f_stat['mtime']))
            p.start()
            p_list.append(p)

# 通过 Queue 获取 Core 解析结果
# --------------------------------------------------------------------------
max_loop = 10000   # 限定最大循环次数，避免死循环
while max_loop > 0:
    while not q_core_stack.empty():
        core_item = q_core_stack.get()
        yield (core_item)
    # 遍历进程列表，依次判断是否执行完成
    for p in p_list:
        p.join(0.01)
    p_list = [x for x in p_list if x.is_alive()]
    max_loop -= 1
    # 进程列表为空，则退出循环
    if len(p_list) == 0 and q_core_stack.empty():
        break

return
$$ language plpythonu;

-- select file_name, modify_time, stack_id, function_name, code_file, code_position from pg_query_corestack_local() where stack_id >= 0;
-- select file_name, modify_time, stack_id, function_name, code_file, code_position from pg_query_corestack_local(clock_timestamp()::timestamp - interval '30 days') where stack_id >= 0;



-- =============================================================================
-- pg_query_corestack
-- ====================
-- 【作用】 主程序，用于并行查询集群各个节点的 Core 堆栈并做汇总展示
-- 【参数】 1. 开始时间
--         2. 结束时间
--         3. 并行度
--         4. 是否打印 notice 信息
-- 【逻辑】 通过调用 pg_query_corestack_local，并发的从各个节点获取堆栈信息
-- 【返回】 Core 堆栈信息表（字段参考 type_core_stack 类型）
-- =============================================================================
drop function if exists pg_query_corestack (pi_begin timestamp, pi_end timestamp, pi_parallel int, pi_notice bool);
create or replace function pg_query_corestack ( pi_begin     timestamp  Default clock_timestamp() - interval '1 month'
                                              , pi_end       timestamp  Default clock_timestamp()
                                              , pi_parallel  int        Default 8
                                              , pi_notice    bool       Default 'false')
returns setof type_core_stack
as $$
from multiprocessing import Process,Queue
q_core_stack = Queue(10000)
p_list = []

res = plpy.execute("select count(*) as cnt from pg_class where relname = 'pgxc_node'")
if res[0]['cnt'] == 0:
    for r_data in plpy.prepare("select *  from pg_query_corestack_local($1, $2, $3, $4)" , ["timestamp", "timestamp", "int", "bool"]).execute([pi_begin, pi_end, pi_parallel, pi_notice]):
        yield ([r_data['node_name'], r_data['file_name'], r_data['modify_time'], r_data['stack_id'], r_data['stack_data'], r_data['function_name'], r_data['function_params'], r_data['code_file'], r_data['code_position']])
else:
    def query_remote(node_name):
        for r_data in plpy.prepare("execute direct on ({}) 'select *  from pg_query_corestack_local($1, $2, $3, $4, $5)'".format(node_name)
                                  , ["timestamp", "timestamp", "int", "bool", "text"]).execute([pi_begin, pi_end, pi_parallel, pi_notice, node_name]):
            q_core_stack.put([r_data['node_name'], r_data['file_name'], r_data['modify_time'], r_data['stack_id'], r_data['stack_data'], r_data['function_name'], r_data['function_params'], r_data['code_file'], r_data['code_position']])

    # 多进程调用各个节点的本地 Core 解析函数
    # --------------------------------------------------------------------------
    for l_node in plpy.execute("select node_name::text as node_name from pgxc_node where node_type in ('C', 'D')"):
        p = Process(target=query_remote, args=(l_node['node_name'], ))
        p.start()
        p_list.append(p)

    # 通过 Queue 获取 Core 解析结果
    # --------------------------------------------------------------------------
    max_loop = 10000   # 限定最大循环次数，避免死循环
    while max_loop > 0:
        while not q_core_stack.empty():
            core_item = q_core_stack.get()
            yield (core_item)
        # 遍历进程列表，依次判断是否执行完成
        for p in p_list:
            p.join(0.01)
        p_list = [x for x in p_list if x.is_alive()]
        max_loop -= 1
        # 进程列表为空，则退出循环
        if len(p_list) == 0 and q_core_stack.empty():
            break

return
$$ language plpythonu;

-- select node_name, file_name, modify_time, stack_id, function_name, code_file, code_position from pg_query_corestack(pi_notice => 'true') where stack_id >= 0;
-- select node_name, file_name, modify_time, stack_id, function_name, code_file, code_position from pg_query_corestack(clock_timestamp()::timestamp - interval '30 days') where stack_id >= 0;



-- =============================================================================
-- 用法实例
-- =============================================================================
-- 1. 集群版，杀掉 gc_m 节点上的 12345 进程
select node_name, file_name, modify_time, stack_id, function_name, code_file, code_position from pg_query_corestack(pi_notice => 'true') where stack_id >= 0;


-- 2. 集群版/单机版，查看当前节点上的 Core 堆栈信息
select file_name, modify_time, stack_id, function_name, code_file, code_position from pg_query_corestack_local(clock_timestamp()::timestamp - interval '7 days') where stack_id >= 0;

-- 单机版输出：
-- NOTICE:  [CURRENT] Get core directory from kernel: /data/coredump
-- NOTICE:  [CURRENT] Get default core directory: /data/danghb/data/adb60zjcmc
-- NOTICE:  [CURRENT] Get core file [/data/coredump/core-postgres-79338-1610420094]        [2021-01-12 10:54:55+08]        [443514880]
-- NOTICE:  [CURRENT] Get core file [/data/coredump/core-postgres-181146-1610967111]       [2021-01-18 18:51:52+08]        [392032256]
-- NOTICE:  [CURRENT] Get core file [/data/coredump/core-postgres-45468-1610527679]        [2021-01-13 16:47:59+08]        [153088000]
-- NOTICE:  [CURRENT] Get core file [/data/coredump/core-postgres-91569-1611568653]        [2021-01-25 17:57:34+08]        [392175616]
-- NOTICE:  [CURRENT] Get core file [/data/coredump/core-postgres-180569-1610967111]       [2021-01-18 18:51:52+08]        [392032256]
-- NOTICE:  [CURRENT] Get core file [/data/coredump/core-postgres-58059-1610418903]        [2021-01-12 10:35:04+08]        [400805888]
-- NOTICE:  [CURRENT] Get core file [/data/coredump/core-postgres-79043-1610420108]        [2021-01-12 10:55:09+08]        [436703232]
-- NOTICE:  [CURRENT] Get core file [/data/coredump/core-postgres-181442-1610967111]       [2021-01-18 18:51:52+08]        [392032256]
-- NOTICE:  [CURRENT] Get core file [/data/coredump/core-postgres-180957-1610967111]       [2021-01-18 18:51:52+08]        [392032256]
-- NOTICE:  [CURRENT] Get core file [/data/coredump/core-postgres-171501-1611557074]       [2021-01-25 14:44:35+08]        [392175616]
-- NOTICE:  [CURRENT] Get core file [/data/coredump/core-postgres-49670-1610527815]        [2021-01-13 16:50:16+08]        [152547328]
-- NOTICE:  [CURRENT] Get core file [/data/coredump/core-postgres-3914-1611557398] [2021-01-25 14:49:58+08]        [392175616]
-- NOTICE:  [CURRENT] Get core file [/data/coredump/core-postgres-71652-1611564061]        [2021-01-25 16:41:01+08]        [392175616]
-- NOTICE:  [CURRENT] Get core file [/data/coredump/core-postgres-181396-1610967111]       [2021-01-18 18:51:52+08]        [392032256]
-- NOTICE:  [CURRENT] Get core file [/data/coredump/core-postgres-58061-1610418903]        [2021-01-12 10:35:04+08]        [443514880]
-- NOTICE:  [CURRENT] Get core file [/data/coredump/core-postgres-19290-1611550063]        [2021-01-25 12:47:43+08]        [392175616]
-- NOTICE:  [CURRENT] Get core file [/data/coredump/core-postgres-58060-1610418903]        [2021-01-12 10:35:04+08]        [443514880]
-- NOTICE:  [CURRENT] Get core file [/data/coredump/core-postgres-181198-1610967111]       [2021-01-18 18:51:52+08]        [392032256]
-- NOTICE:  [CURRENT] Get core file [/data/coredump/core-postgres-181614-1610967111]       [2021-01-18 18:51:52+08]        [390991872]
-- NOTICE:  [CURRENT] Get core file [/data/coredump/core-postgres-180908-1610967111]       [2021-01-18 18:51:52+08]        [392032256]
-- NOTICE:  [CURRENT] Get core file [/data/coredump/core-postgres-181573-1610967111]       [2021-01-18 18:51:52+08]        [390991872]
-- NOTICE:  [CURRENT] Get core file [/data/coredump/core-postgres-147649-1611565765]       [2021-01-25 17:09:26+08]        [392175616]
-- NOTICE:  [CURRENT] Get core file [/data/coredump/core-postgres-27856-1611557656]        [2021-01-25 14:54:17+08]        [392175616]
-- NOTICE:  [CURRENT] Get core file [/data/coredump/core-postgres-79337-1610420094]        [2021-01-12 10:54:55+08]        [443514880]
-- NOTICE:  [CURRENT] Get core file [/data/coredump/core-postgres-180911-1610967112]       [2021-01-18 18:51:53+08]        [392134656]
-- NOTICE:  [CURRENT] Get core file [/data/coredump/core-postgres-79049-1610420108]        [2021-01-12 10:55:09+08]        [436703232]
-- NOTICE:  [CURRENT] Get core file [/data/coredump/core-postgres-79335-1610420094]        [2021-01-12 10:54:55+08]        [400805888]
--  node_name |                   file_name                   |     modify_time     | stack_id |    function_name     |                              code_file                               | code_position
-- -----------+-----------------------------------------------+---------------------+----------+----------------------+----------------------------------------------------------------------+---------------
--  CURRENT   | /data/coredump/core-postgres-45468-1610527679 | 2021-01-13 16:47:59 |        0 | raise                | /usr/lib64/libc.so.6                                                 |
--  CURRENT   | /data/coredump/core-postgres-45468-1610527679 | 2021-01-13 16:47:59 |        1 | abort                | /usr/lib64/libc.so.6                                                 |
--  CURRENT   | /data/coredump/core-postgres-45468-1610527679 | 2021-01-13 16:47:59 |        2 | ExceptionalCondition | /data/danghb/soft_src/adb60zjcmc/src/backend/utils/error/assert.c    | 54
--  CURRENT   | /data/coredump/core-postgres-45468-1610527679 | 2021-01-13 16:47:59 |        3 | PortalRunMulti       | /data/danghb/soft_src/adb60zjcmc/src/backend/tcop/pquery.c           | 1489
--  CURRENT   | /data/coredump/core-postgres-45468-1610527679 | 2021-01-13 16:47:59 |        4 | PortalRun            | /data/danghb/soft_src/adb60zjcmc/src/backend/tcop/pquery.c           | 882
--  CURRENT   | /data/coredump/core-postgres-45468-1610527679 | 2021-01-13 16:47:59 |        5 | exec_simple_query    | /data/danghb/soft_src/adb60zjcmc/src/backend/tcop/postgres.c         | 1681
--  CURRENT   | /data/coredump/core-postgres-45468-1610527679 | 2021-01-13 16:47:59 |        6 | PostgresMain         | /data/danghb/soft_src/adb60zjcmc/src/backend/tcop/postgres.c         | 5146
--  CURRENT   | /data/coredump/core-postgres-45468-1610527679 | 2021-01-13 16:47:59 |        7 | BackendRun           | /data/danghb/soft_src/adb60zjcmc/src/backend/postmaster/postmaster.c | 5239
--  CURRENT   | /data/coredump/core-postgres-45468-1610527679 | 2021-01-13 16:47:59 |        8 | BackendStartup       | /data/danghb/soft_src/adb60zjcmc/src/backend/postmaster/postmaster.c | 4909
--  CURRENT   | /data/coredump/core-postgres-45468-1610527679 | 2021-01-13 16:47:59 |        9 | ServerLoop           | /data/danghb/soft_src/adb60zjcmc/src/backend/postmaster/postmaster.c | 1918
--  CURRENT   | /data/coredump/core-postgres-45468-1610527679 | 2021-01-13 16:47:59 |       10 | PostmasterMain       | /data/danghb/soft_src/adb60zjcmc/src/backend/postmaster/postmaster.c | 1588
--  CURRENT   | /data/coredump/core-postgres-45468-1610527679 | 2021-01-13 16:47:59 |       11 | main                 | /data/danghb/soft_src/adb60zjcmc/src/backend/main/main.c             | 235
--  CURRENT   | /data/coredump/core-postgres-49670-1610527815 | 2021-01-13 16:50:16 |        0 | raise                | /usr/lib64/libc.so.6                                                 |
--  CURRENT   | /data/coredump/core-postgres-49670-1610527815 | 2021-01-13 16:50:16 |        1 | abort                | /usr/lib64/libc.so.6                                                 |
--  CURRENT   | /data/coredump/core-postgres-49670-1610527815 | 2021-01-13 16:50:16 |        2 | ExceptionalCondition | /data/danghb/soft_src/adb60zjcmc/src/backend/utils/error/assert.c    | 54
--  CURRENT   | /data/coredump/core-postgres-49670-1610527815 | 2021-01-13 16:50:16 |        3 | slr_save_resowner    | pg_statement_rollback.c                                              | 638
--  CURRENT   | /data/coredump/core-postgres-49670-1610527815 | 2021-01-13 16:50:16 |        4 | slr_ExecutorStart    | pg_statement_rollback.c                                              | 486
--  CURRENT   | /data/coredump/core-postgres-49670-1610527815 | 2021-01-13 16:50:16 |        5 | ExecutorStart        | /data/danghb/soft_src/adb60zjcmc/src/backend/executor/execMain.c     | 149
--  CURRENT   | /data/coredump/core-postgres-49670-1610527815 | 2021-01-13 16:50:16 |        6 | ProcessQuery         | /data/danghb/soft_src/adb60zjcmc/src/backend/tcop/pquery.c           | 162
--  CURRENT   | /data/coredump/core-postgres-49670-1610527815 | 2021-01-13 16:50:16 |        7 | PortalRunMulti       | /data/danghb/soft_src/adb60zjcmc/src/backend/tcop/pquery.c           | 1418
--  CURRENT   | /data/coredump/core-postgres-49670-1610527815 | 2021-01-13 16:50:16 |        8 | PortalRun            | /data/danghb/soft_src/adb60zjcmc/src/backend/tcop/pquery.c           | 882
--  CURRENT   | /data/coredump/core-postgres-49670-1610527815 | 2021-01-13 16:50:16 |        9 | exec_simple_query    | /data/danghb/soft_src/adb60zjcmc/src/backend/tcop/postgres.c         | 1681
--  CURRENT   | /data/coredump/core-postgres-49670-1610527815 | 2021-01-13 16:50:16 |       10 | PostgresMain         | /data/danghb/soft_src/adb60zjcmc/src/backend/tcop/postgres.c         | 5146
--  CURRENT   | /data/coredump/core-postgres-49670-1610527815 | 2021-01-13 16:50:16 |       11 | BackendRun           | /data/danghb/soft_src/adb60zjcmc/src/backend/postmaster/postmaster.c | 5239
--  CURRENT   | /data/coredump/core-postgres-49670-1610527815 | 2021-01-13 16:50:16 |       12 | BackendStartup       | /data/danghb/soft_src/adb60zjcmc/src/backend/postmaster/postmaster.c | 4909
--  CURRENT   | /data/coredump/core-postgres-49670-1610527815 | 2021-01-13 16:50:16 |       13 | ServerLoop           | /data/danghb/soft_src/adb60zjcmc/src/backend/postmaster/postmaster.c | 1918
--  CURRENT   | /data/coredump/core-postgres-49670-1610527815 | 2021-01-13 16:50:16 |       14 | PostmasterMain       | /data/danghb/soft_src/adb60zjcmc/src/backend/postmaster/postmaster.c | 1588
--  CURRENT   | /data/coredump/core-postgres-49670-1610527815 | 2021-01-13 16:50:16 |       15 | main                 | /data/danghb/soft_src/adb60zjcmc/src/backend/main/main.c             | 235
-- (28 rows)

-- Time: 2083.077 ms (00:02.083)
