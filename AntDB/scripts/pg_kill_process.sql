
-- =============================================================================
-- pg_kill_internal
-- ====================
-- 【作用】 子程序，用于 kill 当前节点的某个进程，根据是否远程节点，有不同的过滤处理逻辑
-- 【参数】 1. 进程 ID
--         2. 当前是否为远程节点
-- 【逻辑】 kill 进程采用 kill(15) + gdb 的方式，尽可能使得进程快速退出
-- 【返回】 当前节点中，被 kill 的进程数，一般都是 0 或者 1
-- =============================================================================
drop function if exists pg_kill_internal (pi_pid int, pi_is_remote boolean);
create or replace function pg_kill_internal ( pi_pid        int
                                            , pi_is_remote  boolean  Default 'false')
returns int
as $$
    import subprocess
    killed_num = 0

    if pi_is_remote:
        # 远程节点
        #   ps -Ao pid,cmd | grep "for PID <PID> from" | grep postgres
        #   kill -15 <PID> 1>/dev/null 2>&1
        #   echo bt | gdb -p <PID> 1>/dev/null 2>&1
        # 26387 postgres: yx yj_db 132.121.107.141(51948) <cluster query> for PID 66880 from cord02
        res=subprocess.Popen('ps -Ao pid,cmd | grep "for PID {} from" | grep postgres | grep -v grep'.format(pi_pid),
                             shell=True,
                             stdout=subprocess.PIPE)
        for x in res.stdout.read().strip().split('\n'):
            x = x.strip()
            if x:
                kill_pid = x.split()[0]
                plpy.notice('Killing [{}]  =>  {}'.format(kill_pid, x))
                subprocess.Popen('kill -15 {} 1>/dev/null 2>&1'.format(kill_pid), shell=True)
                subprocess.Popen('echo bt | gdb -p {} 1>/dev/null 2>&1'.format(kill_pid), shell=True)
                killed_num = killed_num + 1
    else:
        # 当前节点
        #   杀掉当前进程，及其子进程
        #   kill -15 <PID> 1>/dev/null 2>&1
        #   echo bt | gdb -p <PID> 1>/dev/null 2>&1
        res=subprocess.Popen('ps -Ao pid,ppid,cmd | grep {} | grep -v grep'.format(pi_pid),
                             shell=True,
                             stdout=subprocess.PIPE)
        for x in res.stdout.read().strip().split('\n'):
            x = x.strip()
            p_list = x.split()
            if x and (p_list[0] == pi_pid or p_list[1] == pi_pid):
                plpy.notice('Killing [{}]  =>  {}'.format(p_list[0], x))
                subprocess.Popen('kill -15 {} 1>/dev/null 2>&1'.format(p_list[0]), shell=True)
                subprocess.Popen('echo bt | gdb -p {} 1>/dev/null 2>&1'.format(p_list[0]), shell=True)
                killed_num = killed_num + 1
        # res=subprocess.Popen('ps -o pid,cmd -p {} | grep -v "PID CMD"'.format(pi_pid),
        #                      shell=True,
        #                      stdout=subprocess.PIPE)
        # if res.stdout.read().strip():
        #     res=subprocess.Popen('kill -15 {} 1>/dev/null 2>&1'.format(pi_pid), shell=True)
        #     res=subprocess.Popen('echo bt | gdb -p {} 1>/dev/null 2>&1'.format(pi_pid), shell=True)
        #     killed_num = killed_num + 1

    return killed_num
$$ language plpythonu;


-- =============================================================================
-- pg_kill_process
-- ====================
-- 【作用】 主程序，用于 kill 当前节点的某个进程
-- 【参数】 1. 进程 ID
--         2. 进程所在的主节点名称，默认为空，即为当前节点
-- 【逻辑】 调用 pg_kill_internal 完成各个节点上的进程 kill 操作
-- 【返回】 各个节点的 kill 结果 (node_name, killed_count)
-- =============================================================================
drop function if exists pg_kill_process (pi_pid int, pi_node text);
create or replace function pg_kill_process ( pi_pid   int
                                           , pi_node  text  Default null)
returns setof record
as
$$
declare
    l_pgxc_exists bigint;
    l_node_name   text;
    l_target_node text;
    l_node_valid  bigint;
begin
    select count(*) into l_pgxc_exists from pg_class where relname = 'pgxc_node';
    if l_pgxc_exists = 0
    then
      return query select 'CURRENT' as node_name, pg_kill_internal(pi_pid) as killed_count;
    else
        if pi_node is null
        then
            select setting into l_target_node
              from pg_settings
             where name = 'pgxc_node_name';
        else
            select count(*) into l_node_valid
              from pgxc_node
             where node_name = pi_node;
            if l_node_valid = 0
            then
                raise exception 'Node [%] does not exists', pi_node;
            end if;
            l_target_node := pi_node;
        end if;
        for l_node_name in select node_name::text as node_name from pgxc_node where node_type in ('C', 'D')
        loop
          return query execute 'execute direct on ('||l_node_name||') ''select '''''||l_node_name||''''' as node_name, pg_kill_internal('||pi_pid||', '''''||(case when l_node_name = l_target_node then 'false' else 'true' end)||''''')''';
        end loop;
    end if;
end;
$$ language plpgsql;


-- =============================================================================
-- 用法实例
-- =============================================================================
-- 1. 集群版，杀掉 gc_m 节点上的 12345 进程
select * from pg_kill_process(12345, 'gc_m') as (node_name text, killed_count int);

-- 集群版输出：
--  node_name | killed_count
-- -----------+--------------
--  gc_m      |            0
--  cm_1      |            0
--  dm_1      |            0
--  dm_2      |            0
--  dm_3      |            0
-- (5 rows)

-- 2. 集群版/单机版，杀掉当前节点上的 12345 进程
select * from pg_kill_process(12345) as (node_name text, killed_count int);

-- 单机版输出：
--  node_name | killed_count
-- -----------+--------------
--  CURRENT   |            0
-- (1 row)
