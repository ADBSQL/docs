
-- file_name = postgresql-min_time-max_time.idx
-- file_date = log_time|log_position, 单行长度固定为33（包括换行符）
-- =============================================================================
-- 1. 20200605 修复空日志文件导致的查询报错
-- =============================================================================
-- 效率：
-- 1. count 155w 记录(2GB)，单个日志文件大小 10M，耗时25s，平均每秒 6w 记录
-- 2. copy 查询结果到文件，155w 记录(2GB)，耗时38s，平均每秒 4w 记录


create or replace language plpythonu;


-- =============================================================================
-- 待读取文件范围类型
-- =============================================================================
DROP TYPE if exists gvf_log_range_type cascade;
CREATE TYPE gvf_log_range_type
AS ( file_name               text
   , begin_position          bigint
   , end_position            bigint
   );


-- =============================================================================
-- 日志内容对应的返回数据类型
-- =============================================================================
DROP TYPE if exists gvf_log_item_type cascade;
CREATE TYPE gvf_log_item_type
AS ( node_name               text
   , log_time                text
   , user_name               text
   , database_name           text
   , process_id              text
   , connection_from         text
   , session_id              text
   , session_line_num        text
   , command_tag             text
   , session_start_time      text
   , virtual_transaction_id  text
   , transaction_id          text
   , error_severity          text
   , sql_state_code          text
   , message                 text
   , detail                  text
   , hint                    text
   , internal_query          text
   , internal_query_pos      text
   , context                 text
   , query                   text
   , query_pos               text
   , location                text
   , application_name        text
   );



-- =============================================================================
-- 创建新的索引文件
-- =============================================================================
drop function if exists gvf_create_index cascade;
create or replace function gvf_create_index ( pi_logfile_name  text
                                            , pi_debug_level   int  default  0
                                            )
returns void
as $$
import os
import re
import time
pre_time = ""
if pi_debug_level >= 1:
    plpy.notice("{} Open index file [pg_log/{}.idx] for write".format(time.strftime("%Y-%m-%d %H:%M:%S"), pi_logfile_name))
with open("pg_log/{}.idx".format(pi_logfile_name), "w") as idxfile:
    if pi_debug_level >= 1:
        plpy.notice("{} Open csv file [pg_log/{}.csv] for read".format(time.strftime("%Y-%m-%d %H:%M:%S"), pi_logfile_name))
    with open("pg_log/{}.csv".format(pi_logfile_name), "r") as logfile:
        while True:
            read_position = logfile.tell()
            line = logfile.readline()
            if pi_debug_level >= 3:
                plpy.notice("{}     Data [{}]".format(time.strftime("%Y-%m-%d %H:%M:%S"), line))
            if not line:
                if pi_debug_level >= 3:
                    plpy.notice("{}     No data found, End of file".format(time.strftime("%Y-%m-%d %H:%M:%S")))
                break
            # 2020-03-17 10:45:59.001 EDT
            match_time = re.match(r"(\d{4}\-\d{2}\-\d{2}\s+\d{2}:\d{2}:\d{2})\.\d+\s+\w+\,", line)
            if match_time:
                if match_time.group(1) != pre_time:
                    if pi_debug_level >= 3:
                        plpy.notice("{}     {} {:>12d}".format(time.strftime("%Y-%m-%d %H:%M:%S"), match_time.group(1), read_position))
                    idxfile.write("{}{:>13d}\n".format(match_time.group(1), read_position))
                    pre_time = match_time.group(1)
                else:
                    if pi_debug_level >= 3:
                        plpy.notice("{}     Same time".format(time.strftime("%Y-%m-%d %H:%M:%S")))
                    pass
            else:
                if pi_debug_level >= 3:
                    plpy.notice("{}     Not matched".format(time.strftime("%Y-%m-%d %H:%M:%S")))
                pass
if os.path.exists("pg_log/{}.idx".format(pi_logfile_name)):
    pre_time = pre_time.replace("-", "").replace(":", "").replace(" ", "")
    if pi_debug_level >= 1:
        plpy.notice("{} Rename index file [pg_log/{}.idx] to [pg_log/{}-{}.idx]".format(time.strftime("%Y-%m-%d %H:%M:%S"), pi_logfile_name, pi_logfile_name, pre_time))
    os.rename("pg_log/{}.idx".format(pi_logfile_name), "pg_log/{}-{}.idx".format(pi_logfile_name, pre_time))
$$ language plpythonu;


drop function if exists gvf_file_range cascade;
create or replace function gvf_file_range ( pi_begin_time    text default to_char(clock_timestamp() - interval '10 minutes', 'yyyy-mm-dd HH24:mi:ss')
                                          , pi_end_time      text default to_char(clock_timestamp(), 'yyyy-mm-dd HH24:mi:ss')
                                          , pi_debug_level   int  default 0
                                          )
returns setof gvf_log_range_type
as $$
import time
import os

# SQL执行函数
def query_db(sql_stmt):
    if pi_debug_level >= 2:
        plpy.notice("{}   Query [{}]".format(time.strftime("%Y-%m-%d %H:%M:%S"), sql_stmt.format(BT=pi_begin_time, ET=pi_end_time, DL=pi_debug_level)))
    try:
        return plpy.execute(sql_stmt.format(BT=pi_begin_time, ET=pi_end_time, DL=pi_debug_level))
    except plpy.SPIError as e:
        plpy.error("Query error: [{}]".format(e.args))
    return None;

# 二分法查找时间位置
# 索引文件每一行对应一个时间位置，每一行的长度为33（包括换行符）
# 2020-03-17 10:23:59         3276
def get_location(index_file, target_time, index_size):
    with open("pg_log/{}".format(index_file), "r") as f:
        def do_search(search_begin, search_end):
            if pi_debug_level >= 2:
                plpy.notice("{}   Search from [{}] to [{}]".format(time.strftime("%Y-%m-%d %H:%M:%S"), search_begin, search_end))
            mid_position = int((search_end + search_begin)/33/2) * 33
            f.seek(mid_position)
            mid_time = f.readline().strip()
            if pi_debug_level >= 2:
                plpy.notice("{}   Mid [{}] Time [{}]".format(time.strftime("%Y-%m-%d %H:%M:%S"), mid_position, mid_time[0:19]))
            if target_time == mid_time[0:19] or mid_position == 0:
                if pi_debug_level >= 2:
                    plpy.notice("{}   Found [{}]".format(time.strftime("%Y-%m-%d %H:%M:%S"), mid_time[19:]))
                return int(mid_time[19:])
            elif target_time > mid_time[0:19]:
                next_time = f.readline().strip()
                if not next_time:
                    if pi_debug_level >= 2:
                        plpy.notice("{}   Found [{}] because no next time".format(time.strftime("%Y-%m-%d %H:%M:%S"), mid_time[19:]))
                    return -1
                elif target_time <= next_time[0:19]:
                    if pi_debug_level >= 2:
                        plpy.notice("{}   Found next [{}]".format(time.strftime("%Y-%m-%d %H:%M:%S"), next_time[0:19]))
                    return int(next_time[19:])
                else:
                    if pi_debug_level >= 2:
                        plpy.notice("{}   Deep Right [{} - {}]".format(time.strftime("%Y-%m-%d %H:%M:%S"), mid_position, search_end))
                    return do_search(mid_position, search_end)
            else:
                if pi_debug_level >= 2:
                    plpy.notice("{}   Deep Left [{} - {}]".format(time.strftime("%Y-%m-%d %H:%M:%S"), search_begin, mid_position))
                return do_search(search_begin, mid_position)

        return do_search(0, index_size)

# 移除日志文件已删除的 index 文件
index_list = query_db(r"""select i.name
                            from (select name, substr(name, 1, 28) file_name
                                       , to_timestamp(substr(name, 30, 14), 'yyyymmddhh24miss') as max_time
                                    from pg_ls_logdir()
                                   where name ~ '^postgresql[\d\-\_]+\.idx$'
                                 ) as i
                            left join (select substr(name, 1, 28) file_name, size, modification
                                         from pg_ls_logdir()
                                        where name ~ '^postgresql[\d\-\_]+\.csv$'
                                          and size > 0
                                      ) as l
                              on l.file_name = i.file_name
                           where l.file_name is null""")
for index_item in index_list:
    if pi_debug_level >= 1:
        plpy.notice("{} Delete orphan index file [{}]".format(time.strftime("%Y-%m-%d %H:%M:%S"), index_item["name"]))
    os.unlink("pg_log/{}".format(index_item["name"]))

# 移除时间不匹配的 index 文件
index_list = query_db(r"""select i.name
                            from (select substr(name, 1, 28) file_name, size, modification
                                    from pg_ls_logdir()
                                   where name ~ '^postgresql[\d\-\_]+\.csv$'
                                     and to_timestamp(substr(name, 12, 17), 'yyyy-mm-dd_HH24miss') < to_timestamp('{ET}', 'yyyy-mm-dd HH24:mi:ss')
                                     and modification > to_timestamp('{BT}', 'yyyy-mm-dd HH24:mi:ss')
                                     and size > 0
                                 ) as l
                            join (select name, substr(name, 1, 28) file_name
                                       , to_timestamp(substr(name, 30, 14), 'yyyymmddhh24miss') as max_time
                                    from pg_ls_logdir()
                                   where name ~ '^postgresql[\d\-\_]+\.idx$'
                                 ) as i
                              on l.file_name = i.file_name
                           where l.modification != i.max_time""")
for index_item in index_list:
    if pi_debug_level >= 1:
        plpy.notice("{} Delete invalid index file [{}]".format(time.strftime("%Y-%m-%d %H:%M:%S"), index_item["name"]))
    os.unlink("pg_log/{}".format(index_item["name"]))

# 获取没有索引的日志文件，进行索引文件重建
index_list = query_db(r"""select l.name, gvf_create_index(l.file_name, {DL}) res
                            from (select name, substr(name, 1, 28) file_name, size, modification
                                    from pg_ls_logdir()
                                   where name ~ '^postgresql[\d\-\_]+\.csv$'
                                     and to_timestamp(substr(name, 12, 17), 'yyyy-mm-dd_HH24miss') < to_timestamp('{ET}', 'yyyy-mm-dd HH24:mi:ss')
                                     and modification > to_timestamp('{BT}', 'yyyy-mm-dd HH24:mi:ss')
                                     and size > 0
                                 ) as l
                            left join (select substr(name, 1, 28) file_name
                                         from pg_ls_logdir()
                                        where name ~ '^postgresql[\d\-\_]+\.idx$'
                                      ) as i
                              on l.file_name = i.file_name
                           where i.file_name is null""")
if pi_debug_level >= 1:
    for index_item in index_list:
        plpy.notice("{} Create index file for [{}]".format(time.strftime("%Y-%m-%d %H:%M:%S"), index_item["name"]))

# 获取必要的索引文件列表
# LOG_BEGIN < QUERY_END AND LOG_END > QUERY_BEGIN AND QUERY_END > QUERY_BEGIN
# LOG_BEGIN 是日志文件创建时间，并不一定对应日志内容的开始时间： 创建时间 <= 内容时间
index_list = query_db(r"""select name
                            from pg_ls_logdir()
                           where name ~ '^postgresql-[\d\-\_]{{32}}\.idx$'
                             and to_timestamp(substr(name, 12, 17), 'yyyy-mm-dd_HH24miss') <= to_timestamp('{ET}', 'yyyy-mm-dd HH24:mi:ss')
                             and to_timestamp(substr(name, 30, 14), 'yyyymmddhh24miss') >= to_timestamp('{BT}', 'yyyy-mm-dd HH24:mi:ss')
                             and to_timestamp('{ET}', 'yyyy-mm-dd HH24:mi:ss') >= to_timestamp('{BT}', 'yyyy-mm-dd HH24:mi:ss')
                           order by name""")
index_list = [x["name"] for x in index_list]
if pi_debug_level >= 1:
    for index_item in index_list:
        plpy.notice("{} Get required file [{}]".format(time.strftime("%Y-%m-%d %H:%M:%S"), index_item))

# 遍历索引文件
for i, idx_file in enumerate(index_list):
    file_name = "{}.csv".format(idx_file[0:28])
    index_size = os.stat("pg_log/{}".format(idx_file))[6]  # index file size
    begin_position = 0
    end_position = -1

    if i == 0:
        begin_position = get_location(idx_file, pi_begin_time, index_size)
        if pi_debug_level >= 1:
            plpy.notice("{} Query begin location [{}]".format(time.strftime("%Y-%m-%d %H:%M:%S"), begin_position))

    if i == len(index_list) - 1:
        end_position = get_location(idx_file, pi_end_time, index_size)
        if pi_debug_level >= 1:
            plpy.notice("{} Query end location [{}]".format(time.strftime("%Y-%m-%d %H:%M:%S"), end_position))

    if end_position == -1:
        end_position = os.stat("pg_log/{}".format(file_name))[6]  # log file size

    yield ([file_name, begin_position, end_position])

# 最终返回
return
$$ language plpythonu;


-- =============================================================================
-- 查询本节点日志内容
-- =============================================================================
drop function if exists gvf_local_logfile cascade;
create or replace function gvf_local_logfile ( pi_begin_time    text default to_char(clock_timestamp() - interval '10 minutes', 'yyyy-mm-dd HH24:mi:ss')
                                             , pi_end_time      text default to_char(clock_timestamp(), 'yyyy-mm-dd HH24:mi:ss')
                                             , pi_debug_level   int  default 0
                                             )
returns setof gvf_log_item_type
as $$
import time
import csv

# SQL执行函数
def query_db(sql_stmt):
    if pi_debug_level >= 2:
        plpy.notice("{}   Query [{}]".format(time.strftime("%Y-%m-%d %H:%M:%S"), sql_stmt.format(BT=pi_begin_time, ET=pi_end_time, DL=pi_debug_level)))
    try:
        return plpy.execute(sql_stmt.format(BT=pi_begin_time, ET=pi_end_time, DL=pi_debug_level))
    except plpy.SPIError as e:
        plpy.error("Query error: [{}]".format(e.args))
    return None;

for range_item in query_db("select file_name, begin_position, end_position from gvf_file_range('{BT}', '{ET}', {DL})"):
    file_name = range_item['file_name']
    begin_position = range_item['begin_position']
    end_position = range_item['end_position']

    if pi_debug_level >= 1:
        plpy.notice("{} Read [{}] from [{}] to [{}]".format(time.strftime("%Y-%m-%d %H:%M:%S"), file_name, begin_position, end_position))
    with open("pg_log/{}".format(file_name), "r") as f:
        f.seek(begin_position)
        csvReader = csv.reader(f)

        # end_position 为 -1，则读取文件中的所有后续内容
        # if end_position == -1:
        #     for line in csvReader:
        #         yield (["", ] + line)
        # # 有 end_position，读取到指定位置截止
        # else:
        for line in csvReader:
            if f.tell() <= end_position:
                yield (["", ] + line)
            else:
                break

# 最终返回
return
$$ language plpythonu;


-- =============================================================================
-- 查询本节点日志内容函数 gvf_local_logfile 的测试用例
-- =============================================================================
-- select log_time, user_name, database_name, process_id, connection_from from gvf_local_logfile('2020-03-30 12:12:12', '2020-03-31 12:12:12');
-- select count(*) from gvf_local_logfile('2020-01-30 12:12:12', '2020-03-31 12:12:12');


-- =============================================================================
-- 查询全局日志内容
-- =============================================================================
drop function if exists gvf_global_logfile cascade;
create or replace function gvf_global_logfile ( pi_begin_time    text default to_char(clock_timestamp() - interval '10 minutes', 'yyyy-mm-dd HH24:mi:ss')
                                              , pi_end_time      text default to_char(clock_timestamp(), 'yyyy-mm-dd HH24:mi:ss')
                                              , pi_debug_level   int  default 0
                                              )
returns setof gvf_log_item_type
as $$
import time
from multiprocessing import Process,Queue
log_queue = Queue(10000)

# SQL执行函数
def query_db(sql_stmt):
    if pi_debug_level >= 2:
        plpy.notice("{}   Query [{}]".format(time.strftime("%Y-%m-%d %H:%M:%S"), sql_stmt.format(BT=pi_begin_time, ET=pi_end_time, DL=pi_debug_level)))
    try:
        return plpy.execute(sql_stmt.format(BT=pi_begin_time, ET=pi_end_time, DL=pi_debug_level))
    except plpy.SPIError as e:
        plpy.error("Query error: [{}]".format(e.args))
    return None;

# 查询单个节点的函数，用于在多进程中查询的逻辑
def query_node(node_name):
    command = "execute direct on (" + node_name + ") 'select * from gvf_local_logfile(''{BT}'', ''{ET}'', {DL})'"
    if pi_debug_level >= 1:
        plpy.notice("{} Sub-process for [{}] started".format(time.strftime("%Y-%m-%d %H:%M:%S"), node_name))
    node_log = query_db(command)
    for node_item in node_log:
        log_queue.put(( node_name
                      , node_item["log_time"]
                      , node_item["user_name"]
                      , node_item["database_name"]
                      , node_item["process_id"]
                      , node_item["connection_from"]
                      , node_item["session_id"]
                      , node_item["session_line_num"]
                      , node_item["command_tag"]
                      , node_item["session_start_time"]
                      , node_item["virtual_transaction_id"]
                      , node_item["transaction_id"]
                      , node_item["error_severity"]
                      , node_item["sql_state_code"]
                      , node_item["message"]
                      , node_item["detail"]
                      , node_item["hint"]
                      , node_item["internal_query"]
                      , node_item["internal_query_pos"]
                      , node_item["context"]
                      , node_item["query"]
                      , node_item["query_pos"]
                      , node_item["location"]
                      , node_item["application_name"]))
    if pi_debug_level >= 1:
        plpy.notice("{} Sub-process for [{}] finished".format(time.strftime("%Y-%m-%d %H:%M:%S"), node_name))

# 按节点产生子查询进程
process_list = {}
node_list = query_db("select node_name from pgxc_node where node_type in ('C', 'D')")
for node in node_list:
    if pi_debug_level >= 1:
        plpy.notice("{} Start process for [{}]".format(time.strftime("%Y-%m-%d %H:%M:%S"), node["node_name"]))
    p = Process(target=query_node, args=(node["node_name"], ))
    p.start()
    process_list[node["node_name"]] = p
    time.sleep(0.01)

# 通过 Queue 获取子查询结果
max_loop = 10000   # 限定最大循环次数，避免死循环
while max_loop > 0:
    # 依次获取队列中的数据
    if pi_debug_level >= 1:
        plpy.notice("{} [{}] Check queue [{}], process [{}]".format(time.strftime("%Y-%m-%d %H:%M:%S"), max_loop, log_queue.empty(), len(process_list)))
    while not log_queue.empty():
        log_item = log_queue.get()
        yield (log_item)
    # 进程列表为空，则退出循环
    if len(process_list) == 0:
        break
    # 遍历进程列表，依次判断是否执行完成
    node_list = process_list.keys()
    for p_node in node_list:
        process_list[p_node].join(0.05)
        if not process_list[p_node].is_alive():
            if pi_debug_level >= 1:
                plpy.notice("{} Sub-process of node [{}] finished".format(time.strftime("%Y-%m-%d %H:%M:%S"), p_node))
            del process_list[p_node]
    max_loop -= 1

# 最终返回
return
$$ language plpythonu;


-- =============================================================================
-- 查询全局日志内容函数 gvf_global_logfile 的测试用例
-- =============================================================================
-- select count(*) from gvf_global_logfile('2020-01-30 12:12:12', '2020-03-31 12:12:12');




-- =============================================================================
-- 全局日志即时显示服务（无csv格式解析）
-- =============================================================================
drop function if exists gvf_read_logfile cascade;
create or replace function gvf_read_logfile ( pi_file           text
                                            , po_read_position  bigint  default 0
                                            , pi_end_position   bigint  default -1
                                            , pi_line_limit     int     default 100
                                            , pi_re_filter      text    default ''
                                            )
returns setof text
as $$
import re
import os

end_position = os.stat(pi_file)[6] if pi_end_position == -1 else pi_end_position
read_limit = pi_line_limit
with open(pi_file, "r", buffering=0) as f:
    f.seek(po_read_position)
    re_time_filter = re.compile(r"\d{4}\-\d{2}\-\d{2}\s+\d{2}:\d{2}:\d{2}\.\d+\s+\w+\,")
    re_filter = re.compile(pi_re_filter, flags=re.I)
    log_line = ''
    last_pos = po_read_position
    for line in f.xreadlines():
        last_pos += len(line)
        if last_pos > end_position:
            break
        elif re_time_filter.match(line):
            if log_line and re_filter.search(log_line):
                yield log_line.strip()
                read_limit -= 1
                if read_limit <= 0:
                    yield 'STOP_LIMIT:{}'.format(last_pos)
                    log_line = ''
                    break
            log_line = line
        else:
            log_line += line

    if log_line and re_filter.search(log_line):
        yield log_line.strip()

# 最终返回
return
$$ language plpythonu;


-- select * from gvf_read_logfile('pg_log/postgresql-2020-06-09_000000.csv', '0', -1, 10, 'hongye.+select[\s\*]+from');
-- select * from gvf_read_logfile('pg_log/postgresql-2020-06-09_000000.csv', '0', -1, 10, 'hongye.+select.+from');
-- STOP_LIMIT:28672
