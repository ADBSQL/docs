
-- 创建 dbms_job 相关 schema 和配置表
-- =============================================================================
create schema dbms_job;
drop table if exists dbms_job.antdb_job_config;
create table if not exists dbms_job.antdb_job_config
(
    job_id               serial        constraint pk_antdb_job_config_id primary key,
    job_user             text,
    job_schema           text,
    last_date            timestamp,
    next_date            timestamp,
    broken               text          default 'N',
    job_interval         text,
    what                 text
);

drop table if exists dbms_job.antdb_job_log;
create table if not exists dbms_job.antdb_job_log
(
    job_id               int,
    run_time             timestamp,
    complete_time        timestamp,
    run_message          text
);
CREATE INDEX idx_antdb_job_log_job_Id on dbms_job.antdb_job_log(job_id);




-- 创建 submit 函数
-- =============================================================================
/*ora*/
create or replace function dbms_job.submit_internal( p_what       text
                                                   , p_next_date  timestamp    default clock_timestamp()
                                                   , p_interval   text         default null
                                                   , p_no_parse   boolean      default 'false'
                                                   , p_instance   int          default 0
                                                   , p_force      boolean      default 'false')
return int
as $$
declare
    l_job_id       int;
    l_next_date    timestamp;
begin
    if p_interval is not null
    then
      execute immediate '/*ora*/ select '||p_interval into l_next_date;
    end if;
    insert into dbms_job.antdb_job_config (job_user, job_schema, next_date, job_interval, what)
    values (current_user(), current_schema(), p_next_date, p_interval, p_what) RETURNING job_id into l_job_id;
    return l_job_id;
end $$;


-- 创建 submit 函数的重载，p_next_date 接收时区时间类型
-- =============================================================================
/*ora*/
create or replace function dbms_job.submit( p_what       text
                                          , p_next_date  timestamp    default clock_timestamp()
                                          , p_interval   text         default null
                                          , p_no_parse   boolean      default 'false'
                                          , p_instance   int          default 0
                                          , p_force      boolean      default 'false')
return int
as $$
begin
    return dbms_job.submit_internal(case when p_what ~* '\A\s*(select|call)\s+' then p_what else 'select '||p_what end, p_next_date, p_interval, p_no_parse, p_instance, p_force);
end $$;

/*ora*/
create or replace function dbms_job.submit( p_what       text
                                          , p_next_date  timestamp with time zone default clock_timestamp()
                                          , p_interval   text         default null
                                          , p_no_parse   boolean      default 'false'
                                          , p_instance   int          default 0
                                          , p_force      boolean      default 'false')
return int
as $$
begin
    return dbms_job.submit_internal(case when p_what ~* '\A\s*(select|call)\s+' then p_what else 'select '||p_what end, p_next_date::timestamp, p_interval, p_no_parse, p_instance, p_force);
end $$;


-- 创建 run 函数，用于手动执行一个 job
-- =============================================================================
/*ora*/
create or replace function dbms_job.get_next_time(pi_job_interval text)
return timestamp
as $$
declare
    l_next          timestamp;
begin
    execute immediate '/*ora*/ select '||pi_job_interval into l_next;
    return l_next;
end;
$$;

/*pg*/
create or replace function dbms_job.run( p_job_id     int
                                       , p_force      boolean      default 'false')
returns void
as $$
declare

    l_schema        text;
    l_job_interval  text;
    l_job_what      text;
    l_next          timestamp;
begin
    execute 'set lock_timeout=1';
    update dbms_job.antdb_job_config
       set last_date = next_date
     where job_id = p_job_id
    returning job_interval, what, job_schema
      into l_job_interval, l_job_what, l_schema;
    execute 'set lock_timeout=0';

    select dbms_job.get_next_time(l_job_interval) into l_next;

    raise notice 'execute job [%]', p_job_id;
    execute 'set search_path = '''||l_schema||''',''public''';
    execute l_job_what;

    if l_job_interval is null
    then
        raise notice 'delete one time job [%] [%]', p_job_id, l_job_what;
        delete from dbms_job.antdb_job_config where job_id = p_job_id;
    else
        raise notice 'set next time [%] [%]', p_job_id, l_next;
        update dbms_job.antdb_job_config set next_date = l_next where job_id = p_job_id;
    end if;
end $$ language plpgsql;


-- 创建 remove 函数，用于杀掉正在运行的 Job 进程
-- =============================================================================
/*pg*/
create or replace function dbms_job.kill_job ( p_job_id  int )
returns void
as $$
declare
  l_xc_exists  bigint;
  l_node       record;
  l_sess       record;
begin
  select count(*) into l_xc_exists from pg_class where relname = 'pgxc_node';
  if l_xc_exists = 1
  then
    for l_node in select node_name from pgxc_node where node_type = 'C'
    loop
      for l_sess in execute ' execute direct on ('||l_node.node_name||') ''
                              select pid from pg_stat_activity
                               where regexp_match(query,''''^select dbms_job.run\(\d+\)[\s;]*$'''') is not null
                                 and regexp_replace(query,''''[^\d]+'''','''''''',''''g'''')::int = '||p_job_id||''''
      loop
        execute 'execute direct on ('||l_node.node_name||') ''select pg_terminate_backend('||l_sess.pid||')''';
      end loop;
    end loop;
  else
    for l_sess in select pid from pg_stat_activity
                   where regexp_match(query,'^select dbms_job.run\(\d+\)$') is not null
                     and regexp_replace(query,'[^\d]+','','g')::int = p_job_id
    loop
      select pg_terminate_backend(l_sess.pid);
    end loop;
  end if;
end $$ language plpgsql;


-- 创建 remove 函数，用于移除一个 job
-- =============================================================================
/*ora*/
create or replace procedure dbms_job.remove( p_job_id  int
                                           , p_force   boolean   default 'false')
as $$
begin

  -- 清理残留进程
  if p_force
  then
    select dbms_job.kill_job(p_job_id);
  end if;

  -- 删除 Job 配置和日志
  delete from dbms_job.antdb_job_config where job_id = p_job_id;
  delete from dbms_job.antdb_job_log    where job_id = p_job_id;
end $$;


-- 创建 what 函数，用于修改 what 命令
-- =============================================================================
/*ora*/
create or replace procedure dbms_job.what( p_job_id  int
                                         , p_what    text
                                         , p_force   boolean   default 'false')
as $$
begin

  -- 清理残留进程
  if p_force
  then
    select dbms_job.kill_job(p_job_id);
  end if;

  update dbms_job.antdb_job_config set what = p_what where job_id = p_job_id;
end $$;


-- 创建 next_date 函数，用于修改 next_date 属性
-- =============================================================================
/*ora*/
create or replace procedure dbms_job.next_date( p_job_id       int
                                              , p_next_date    timestamp
                                              , p_force        boolean   default 'false')
as $$
begin

  -- 清理残留进程
  if p_force
  then
    select dbms_job.kill_job(p_job_id);
  end if;

  update dbms_job.antdb_job_config set next_date = p_next_date where job_id = p_job_id;
end $$;

/*ora*/
create or replace procedure dbms_job.next_date( p_job_id       int
                                              , p_next_date    timestamp with time zone
                                              , p_force        boolean   default 'false')
as $$
begin

  -- 清理残留进程
  if p_force
  then
    select dbms_job.kill_job(p_job_id);
  end if;

  update dbms_job.antdb_job_config set next_date = p_next_date where job_id = p_job_id;
end $$;


-- 创建 interval 函数，用于修改 interval 属性
-- =============================================================================
/*ora*/
create or replace procedure dbms_job.interval( p_job_id       int
                                             , p_interval     text
                                             , p_force        boolean   default 'false')
as $$
declare
  l_next_date    timestamp;
begin

  -- 清理残留进程
  if p_force
  then
    select dbms_job.kill_job(p_job_id);
  end if;

  execute immediate '/*ora*/ select '||p_interval into l_next_date;
  update dbms_job.antdb_job_config set job_interval = p_interval where job_id = p_job_id;
end $$;


-- 创建 change 函数，用于修改 job 属性
-- =============================================================================
/*ora*/
create or replace procedure dbms_job.change( p_job_id       int
                                           , p_what         text
                                           , p_next_date    timestamp
                                           , p_interval     text
                                           , p_instance     int       default 0
                                           , p_force        boolean   default 'false')
as $$
declare
  l_next_date    timestamp;
begin

  -- 清理残留进程
  if p_force
  then
    select dbms_job.kill_job(p_job_id);
  end if;

  execute immediate '/*ora*/ select '||p_interval into l_next_date;
  update dbms_job.antdb_job_config
     set job_interval = p_interval
       , next_date = p_next_date
       , what = p_what
   where job_id = p_job_id;
end $$;

/*ora*/
create or replace procedure dbms_job.change( p_job_id       int
                                           , p_what         text
                                           , p_next_date    timestamp with time zone
                                           , p_interval     text
                                           , p_instance     int       default 0
                                           , p_force        boolean   default 'false')
as $$
declare
  l_next_date    timestamp;
begin

  -- 清理残留进程
  if p_force
  then
    select dbms_job.kill_job(p_job_id);
  end if;

  execute immediate '/*ora*/ select '||p_interval into l_next_date;
  update dbms_job.antdb_job_config
     set job_interval = p_interval
       , next_date = p_next_date
       , what = p_what
   where job_id = p_job_id;
end $$;


-- 创建 broken 函数，用于修改 job 状态
-- =============================================================================
/*ora*/
create or replace procedure dbms_job.broken( p_job_id       int
                                           , p_broken       boolean
                                           , p_force        boolean   default 'false')
as $$
begin

  -- 清理残留进程
  if p_force
  then
    select dbms_job.kill_job(p_job_id);
  end if;

  update dbms_job.antdb_job_config
     set broken = case when p_broken then 'Y' else 'N' end
   where job_id = p_job_id;
end $$;

/*ora*/
create or replace procedure dbms_job.broken( p_job_id       int
                                           , p_broken       boolean
                                           , p_next_date    timestamp
                                           , p_force        boolean   default 'false')
as $$
begin

  -- 清理残留进程
  if p_force
  then
    select dbms_job.kill_job(p_job_id);
  end if;

  update dbms_job.antdb_job_config
     set broken = case when p_broken then 'Y' else 'N' end
       , next_date = p_next_date
   where job_id = p_job_id;
end $$;

/*ora*/
create or replace procedure dbms_job.broken( p_job_id       int
                                           , p_broken       boolean
                                           , p_next_date    timestamp with time zone
                                           , p_force        boolean   default 'false')
as $$
begin

  -- 清理残留进程
  if p_force
  then
    select dbms_job.kill_job(p_job_id);
  end if;

  update dbms_job.antdb_job_config
     set broken = case when p_broken then 'Y' else 'N' end
       , next_date = p_next_date
   where job_id = p_job_id;
end $$;




-- 加入 Linux crontab 进行调度，每分钟调度一次，调度在 gtm 节点执行
-- =============================================================================
cat > antdb_job_worker.sh <<"EOF"
SCRIPT_HOME=/data/hongye/scripts
LD_LIBRARY_PATH=/data/hongye/app/python3/lib:/data/hongye/app/antdb_5.0_cluster/lib:/usr/local/lib/:/usr/lib64/:/lib64:.
PATH=/data/hongye/app/antdb_5.0_cluster/bin:/data/hongye/app/python3/bin:/data/sy/jdk/jdk1.8.0_191/bin:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/home/hongye/.local/bin:/home/hongye/bin:.

DB_OPTION=$1
JOB_INFO=$2

JOB_ID=`echo $JOB_INFO | cut -d '|' -f 1`
JOB_USER=`echo $JOB_INFO | cut -d '|' -f 2`
BEGIN_TIME=`date +%Y%m%d%H%M%S`
echo "Run job [$JOB_ID] using [$JOB_USER] at: $BEGIN_TIME"
JOB_RESULT=`psql $DB_OPTION -U $JOB_USER  -c "select dbms_job.run($JOB_ID)" 2>&1`

END_TIME=`date +%Y%m%d%H%M%S`
JOB_RESULT=${JOB_RESULT//\'/\'\'}
#JOB_RESULT=${JOB_RESULT//\"/\\\"}
echo "Job end at: $END_TIME"
echo "Job result: $JOB_RESULT"
psql $DB_OPTION -c "insert into dbms_job.antdb_job_log (job_id,run_time,complete_time,run_message) select $JOB_ID, to_timestamp('$BEGIN_TIME', 'YYYYMMDDHH24MISS'), to_timestamp('$END_TIME', 'YYYYMMDDHH24MISS'), '$JOB_RESULT' where '$JOB_RESULT' not like '%lock timeout%update dbms_job.antdb_job_config%'"
EOF



cat > antdb_job_scheduler.sh <<"EOF"
SCRIPT_HOME=/data/hongye/scripts
LD_LIBRARY_PATH=/data/hongye/app/python3/lib:/data/hongye/app/antdb_5.0_cluster/lib:/usr/local/lib/:/usr/lib64/:/lib64:.
PATH=/data/hongye/app/antdb_5.0_cluster/bin:/data/hongye/app/python3/bin:/data/sy/jdk/jdk1.8.0_191/bin:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/home/hongye/.local/bin:/home/hongye/bin:.

mkdir $SCRIPT_HOME/logs

db_option='-At -h 10.21.20.175 -p 55202 -d postgres'
for x in `psql $db_option -c "select job_id, job_user from dbms_job.antdb_job_config where broken = 'N' and next_date < clock_timestamp() + interval '30 seconds'"`
do
  JOB_ID=`echo $x | cut -d '|' -f 1`
  bash $SCRIPT_HOME/antdb_job_worker.sh "$db_option" "$x" 1>$SCRIPT_HOME/logs/worker_$JOB_ID.log 2>&1 &
done
EOF

* * * * * bash /data/hongye/scripts/antdb_job_scheduler.sh >>/data/hongye/scripts/logs/antdb_job_`date +"\%Y\%m\%d"`.log 2>>/data/hongye/scripts/logs/antdb_job_`date +"\%Y\%m\%d"`.log




-- 一些测试相关的命令
-- =============================================================================
create table test_job_log (id int, insert_time timestamp);

delete from dbms_job.antdb_job_config;
delete from dbms_job.antdb_job_log;
delete from test_job_log;


create function p_insert (p_value  int) returns void
as $$
insert into test_job_log values(p_value, clock_timestamp());
$$ language sql;


-- 立即执行，并且每隔 1 分钟执行一次
set grammar to postgres;
select dbms_job.submit( 'select p_insert(1)'
                      , clock_timestamp()::timestamp
                      , 'clock_timestamp() + interval ''1 minutes''');

-- 立即执行，并且每隔 1 分钟执行一次，错误的命令
select dbms_job.submit_internal( 'insert into test_job_log_not_exists values(1, clock_timestamp());'
                               , clock_timestamp()::timestamp
                               , 'clock_timestamp() + interval ''1 minutes''');

-- Oracle 语法下，每分钟执行
set grammar to oracle;
select dbms_job.submit( 'p_insert(11);'
                      , sysdate
                      , 'sysdate + 1/1440');

-- 立即执行，并且每隔 3 分钟执行一次
select dbms_job.submit( 'insert into test_job_log values(3, clock_timestamp());'
                      , clock_timestamp()::timestamp
                      , 'clock_timestamp() + interval ''3 minutes''');

-- 每天凌晨 1 点执行
select dbms_job.submit( 'insert into test_job_log values(11, clock_timestamp());'
                      , clock_timestamp()::date::timestamp + interval '25 hours'
                      , 'clock_timestamp()::date::timestamp + interval ''25 hours''');

-- 立即执行，且只执行一次
select dbms_job.submit('insert into test_job_log values(100, clock_timestamp());'
                      , clock_timestamp()::timestamp);


select dbms_job.submit( 'insert into test_job_log values(2, clock_timestamp());'
                      , clock_timestamp()::timestamp
                      , 'clock_timestamp() + interval ''10 minutes''');
select dbms_job.submit( 'select pg_sleep(1000);'
                      , clock_timestamp()::timestamp
                      , 'clock_timestamp() + interval ''1 minutes''');


select dbms_job.run(1);
select dbms_job.run(2);


select * from dbms_job.antdb_job_config;
select * from test_job_log;
