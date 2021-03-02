
-- =============================================================================
-- Basic function: query_gv_views
-- =============================================================================
drop function query_gv_views cascade;
create or replace function query_gv_views (pi_schema  varchar, pi_view_name  varchar)
returns setof record
as
$$
declare
  l_node_record record;
begin
  for l_node_record in select oid as node_oid, node_name, node_type, node_port, node_host from pgxc_node where node_type in ('C', 'D')
  loop
    return query execute 'execute direct on ('||l_node_record.node_name||') ''select '||l_node_record.node_oid||' as node_oid, '''''||l_node_record.node_name||''''' as node_name, '''''||l_node_record.node_type||''''' as node_type, * from '||pi_schema||'.'||pi_view_name||' '' ';
  end loop;
end;
$$ language plpgsql;


-- =============================================================================
-- Global view for pg_locks
-- Convert relation from oid to name
-- =============================================================================
-- Create function query_gv_locks
create or replace function query_gv_locks ()
returns setof record
as
$$
declare
  l_node_record record;
begin
  for l_node_record in select oid as node_oid, node_name, node_type, node_port, node_host from pgxc_node where node_type in ('C', 'D')
  loop
    return query execute 'execute direct on ('||l_node_record.node_name||') ''select '||l_node_record.node_oid||' as node_oid, '''''||l_node_record.node_name||''''' as node_name, '''''||l_node_record.node_type||''''' as node_type, locktype, c.relnamespace::regnamespace::text as owner, c.relname::text as object_name, page, tuple, virtualxid, transactionid, classid, objid, objsubid, virtualtransaction, pid, mode, granted, fastpath from pg_locks l left join pg_class c on l.relation = c.oid''';
  end loop;
end;
$$ language plpgsql;

-- Global view for [gv_locks]
drop view if exists gv_locks cascade;
create or replace view gv_locks
as
select * from query_gv_locks()
as
t(node_oid int,node_name text,node_type text,locktype text,owner text,object_name text,page integer,tuple smallint,virtualxid text,transactionid xid,classid oid,objid oid,objsubid smallint,virtualtransaction text,pid integer,mode text,granted boolean,fastpath boolean);


-- =============================================================================
-- Other global view
-- =============================================================================
-- Global view for [gv_stat_activity]
drop view if exists gv_stat_activity;
create or replace view gv_stat_activity
as
select * from query_gv_views('pg_catalog', 'pg_stat_activity')
as
t(node_oid int,node_name text,node_type text,datid oid,datname name,pid integer,usesysid oid,usename name,application_name text,client_addr inet,client_hostname text,client_port integer,backend_start timestamp with time zone,xact_start timestamp with time zone,query_start timestamp with time zone,state_change timestamp with time zone,wait_event_type text,wait_event text,state text,backend_xid xid,backend_xmin xid,query text,backend_type text);

-- Global view for blocking session [gv_blocking_session, gv_blocking_session_brief], depends on gv_stat_activity
Drop view if exists gv_blocking_session cascade;
create view gv_blocking_session
as
with session_relation as (select node_name, pid, node_type, backend_xid
                               , max(case when application_name = 'pgxc' then null else node_name end) over (PARTITION by backend_xid::text) as parent_node
                               , max(case when application_name = 'pgxc' then null else pid end) over (PARTITION by backend_xid::text) as parent_pid
                            from gv_stat_activity
                           where backend_xid is not null),
     all_lock as (select s.parent_node as node_name, s.parent_pid as pid, l.transactionid, l.owner, l.object_name, l.page, l.tuple, l.granted
                    from gv_locks l
                    join session_relation s on l.node_name = s.node_name and l.pid = s.pid
                   where l.transactionid is not null or l.object_name is not null
                 ),
     lock_by_xact as (select node_name, pid, transactionid from all_lock where transactionid is not null and not granted),
     lock_by_tuple as (select node_name, pid, owner, object_name, page, tuple, transactionid from all_lock where object_name is not null and not granted)
select rs.node_name run_node, rs.pid run_pid, rs.usename run_user, rs.application_name as run_application, rs.client_addr as run_client_addr, rs.client_hostname as run_client_hostname, rs.client_port as run_client_port, rs.backend_start as run_backend_start, rs.xact_start as run_xact_start, rs.query_start as run_query_start, rs.wait_event_type as run_wait_event_type, rs.wait_event as run_wait_event, rs.state as run_state, rs.backend_xid as run_backend_xid, rs.backend_xmin as run_backend_xmin, rs.query as run_query, rs.backend_type as run_backend_type
     , null as owner, null as object_name
     , ws.node_name wait_node, ws.pid wait_pid, ws.usename wait_user, ws.application_name as wait_application, ws.client_addr as wait_client_addr, ws.client_hostname as wait_client_hostname, ws.client_port as wait_client_port, ws.backend_start as wait_backend_start, ws.xact_start as wait_xact_start, ws.query_start as wait_query_start, ws.wait_event_type as wait_wait_event_type, ws.wait_event as wait_wait_event, ws.state as wait_state, ws.backend_xid as wait_backend_xid, ws.backend_xmin as wait_backend_xmin, ws.query as wait_query, ws.backend_type as wait_backend_type
  from all_lock as r
     , lock_by_xact as w
     , gv_stat_activity as rs
     , gv_stat_activity as ws
 where r.transactionid = w.transactionid
   and r.granted and (w.node_name != r.node_name or w.pid != r.pid)
   and r.node_name = rs.node_name and r.pid = rs.pid
   and w.node_name = ws.node_name and w.pid = ws.pid
 union
select rs.node_name run_node, rs.pid run_pid, rs.usename run_user, rs.application_name as run_application, rs.client_addr as run_client_addr, rs.client_hostname as run_client_hostname, rs.client_port as run_client_port, rs.backend_start as run_backend_start, rs.xact_start as run_xact_start, rs.query_start as run_query_start, rs.wait_event_type as run_wait_event_type, rs.wait_event as run_wait_event, rs.state as run_state, rs.backend_xid as run_backend_xid, rs.backend_xmin as run_backend_xmin, rs.query as run_query, rs.backend_type as run_backend_type
     , r.owner, r.object_name
     , ws.node_name wait_node, ws.pid wait_pid, ws.usename wait_user, ws.application_name as wait_application, ws.client_addr as wait_client_addr, ws.client_hostname as wait_client_hostname, ws.client_port as wait_client_port, ws.backend_start as wait_backend_start, ws.xact_start as wait_xact_start, ws.query_start as wait_query_start, ws.wait_event_type as wait_wait_event_type, ws.wait_event as wait_wait_event, ws.state as wait_state, ws.backend_xid as wait_backend_xid, ws.backend_xmin as wait_backend_xmin, ws.query as wait_query, ws.backend_type as wait_backend_type
  from all_lock as r
     , lock_by_tuple as w
     , gv_stat_activity as rs
     , gv_stat_activity as ws
 where w.owner = r.owner and w.object_name = r.object_name and w.page = r.page and w.tuple = r.tuple
   and (r.node_name != w.node_name or r.pid != w.pid) and r.granted
   and r.node_name = rs.node_name and r.pid = rs.pid
   and w.node_name = ws.node_name and w.pid = ws.pid;

Drop view if exists gv_blocking_session_brief cascade;
create view gv_blocking_session_brief
as
select run_node||':'||run_pid as run_node_pid, run_user, run_wait_event, coalesce(run_application::text, '')||'@'||coalesce(run_client_addr::text, '127.0.0.1') as run_application, run_query
     , owner, object_name
     , wait_node||':'||wait_pid as wait_node_pid, wait_user, coalesce(wait_application::text, '')||'@'||coalesce(wait_client_addr::text, '127.0.0.1') as wait_application, wait_query
  from gv_blocking_session;


-- Global view for [gv_stat_all_tables]
drop view if exists gv_stat_all_tables;
create or replace view gv_stat_all_tables
as
select schemaname
     , relname
     , sum(seq_scan) as seq_scan
     , sum(seq_tup_read) as seq_tup_read
     , sum(idx_scan) as idx_scan
     , sum(idx_tup_fetch) as idx_tup_fetch
     , sum(n_tup_ins) as n_tup_ins
     , sum(n_tup_upd) as n_tup_upd
     , sum(n_tup_del) as n_tup_del
     , sum(n_tup_hot_upd) as n_tup_hot_upd
     , max(n_live_tup) as n_live_tup
     , max(n_dead_tup) as n_dead_tup
     , sum(n_mod_since_analyze) as n_mod_since_analyze
     , max(last_vacuum) as last_vacuum
     , max(last_autovacuum) as last_autovacuum
     , max(last_analyze) as last_analyze
     , max(last_autoanalyze) as last_autoanalyze
     , sum(vacuum_count) as vacuum_count
     , sum(autovacuum_count) as autovacuum_count
     , sum(analyze_count) as analyze_count
     , sum(autoanalyze_count) as autoanalyze_count
  from query_gv_views('pg_catalog', 'pg_stat_all_tables')
    as t(node_oid int,node_name text,node_type text
        ,relid oid,schemaname name,relname name,seq_scan bigint,seq_tup_read bigint,idx_scan bigint,idx_tup_fetch bigint,n_tup_ins bigint,n_tup_upd bigint,n_tup_del bigint,n_tup_hot_upd bigint,n_live_tup bigint,n_dead_tup bigint,n_mod_since_analyze bigint,last_vacuum timestamp with time zone,last_autovacuum timestamp with time zone,last_analyze timestamp with time zone,last_autoanalyze timestamp with time zone,vacuum_count bigint,autovacuum_count bigint,analyze_count bigint,autoanalyze_count bigint
        )
 where node_type = 'C'
 group by schemaname, relname;


-- Global view for [gv_stat_archiver]
drop view if exists gv_stat_archiver;
create or replace view gv_stat_archiver
as
select *
  from query_gv_views('pg_catalog', 'pg_stat_archiver')
    as t(node_oid int,node_name text,node_type text
        ,archived_count bigint,last_archived_wal text,last_archived_time timestamp with time zone,failed_count bigint,last_failed_wal text,last_failed_time timestamp with time zone,stats_reset timestamp with time zone
        );


-- Global view for [gv_stat_bgwriter]
drop view if exists gv_stat_bgwriter;
create or replace view gv_stat_bgwriter
as
select *
  from query_gv_views('pg_catalog', 'pg_stat_bgwriter')
    as t(node_oid int,node_name text,node_type text
        ,checkpoints_timed bigint,checkpoints_req bigint,checkpoint_write_time double precision,checkpoint_sync_time double precision,buffers_checkpoint bigint,buffers_clean bigint,maxwritten_clean bigint,buffers_backend bigint,buffers_backend_fsync bigint,buffers_alloc bigint,stats_reset timestamp with time zone
        );


-- Global view for [gv_stat_database]
drop view if exists gv_stat_database;
create or replace view gv_stat_database
as
select datname
     , sum(numbackends) as numbackends
     , sum(xact_commit) as xact_commit
     , sum(xact_rollback) as xact_rollback
     , sum(blks_read) as blks_read
     , sum(blks_hit) as blks_hit
     , sum(tup_returned) as tup_returned
     , sum(tup_fetched) as tup_fetched
     , sum(tup_inserted) as tup_inserted
     , sum(tup_updated) as tup_updated
     , sum(tup_deleted) as tup_deleted
     , sum(conflicts) as conflicts
     , sum(temp_files) as temp_files
     , sum(temp_bytes) as temp_bytes
     , sum(deadlocks) as deadlocks
     , sum(blk_read_time) as blk_read_time
     , sum(blk_write_time) as blk_write_time
     , max(stats_reset) as stats_reset
  from query_gv_views('pg_catalog', 'pg_stat_database')
    as t(node_oid int,node_name text,node_type text
        ,datid oid,datname name,numbackends integer,xact_commit bigint,xact_rollback bigint,blks_read bigint,blks_hit bigint,tup_returned bigint,tup_fetched bigint,tup_inserted bigint,tup_updated bigint,tup_deleted bigint,conflicts bigint,temp_files bigint,temp_bytes bigint,deadlocks bigint,blk_read_time double precision,blk_write_time double precision,stats_reset timestamp with time zone
        )
 group by datname;



-- Global view for [gv_stat_database_conflicts]
drop view if exists gv_stat_database_conflicts;
create or replace view gv_stat_database_conflicts
as
select datname
     , sum(confl_tablespace) as confl_tablespace
     , sum(confl_lock) as confl_lock
     , sum(confl_snapshot) as confl_snapshot
     , sum(confl_bufferpin) as confl_bufferpin
     , sum(confl_deadlock) as confl_deadlock
  from query_gv_views('pg_catalog', 'pg_stat_database_conflicts')
    as t(node_oid int,node_name text,node_type text
        ,datid oid,datname name,confl_tablespace bigint,confl_lock bigint,confl_snapshot bigint,confl_bufferpin bigint,confl_deadlock bigint
        )
 group by datname;


-- Global view for [gv_stat_wal_receiver]
-- drop view if exists gv_stat_wal_receiver;
-- create or replace view gv_stat_wal_receiver
-- as
-- select *
--   from query_gv_views('pg_catalog', 'pg_stat_wal_receiver')
--     as t(node_oid int,node_name text,node_type text
--         ,pid integer,status text,receive_start_lsn pg_lsn,receive_start_tli integer,received_lsn pg_lsn,received_tli integer,last_msg_send_time timestamp with time zone,last_msg_receipt_time timestamp with time zone,latest_end_lsn pg_lsn,latest_end_time timestamp with time zone,slot_name text,sender_host text,sender_port integer,conninfo text
--         );
