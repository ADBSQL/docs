#!/usr/bin/env python
# -*- encoding: utf-8 -*-
"""
    Copyright by HongyeDBA
"""

import os
import sys
import time
import getopt
import signal
import datetime
from multiprocessing import Queue, Process
from multiprocessing.queues import Empty


# 定义全局变量
__SCRIPT_VERSION = '1.0.0'
global_queue_list = {}
global_batch_size = 32
global_db_host = os.environ['PGHOST'] if 'PGHOST' in os.environ else '127.0.0.1'
global_db_port = os.environ['PGPORT'] if 'PGPORT' in os.environ else '5432'
global_db_name = os.environ['PGDATABASE'] if 'PGDATABASE' in os.environ else 'postgres'
global_db_user = os.environ['PGUSER'] if 'PGUSER' in os.environ else os.environ['USER']
global_db_pass = 'password'
now_time=datetime.datetime.now()
global_begin_time = (now_time + datetime.timedelta(minutes = -1)).strftime('%Y-%m-%d %H:%M:%S')
global_end_time = ''
global_re_filter = ''
global_node_filter = '*'
global_show_all = False
global_continue = False
global_continue_status = {}
global_db_conn = {}
global_command_mode = 'psql'   # MODE: psql/psycopg2
global_log_count = 0
global_worker_list = {}


# 解析命令行参数
my_options, left_argvs = getopt.getopt(sys.argv[1:], 'hvH:P:D:U:W:b:e:f:n:s:ac', ['help', 'version', 'host=', 'port=', 'database=', 'user=', 'password=', 'begin=', 'end=', 're_filter=', 'node_filter=', 'batch_size=', 'all', 'continue'])

option_lists = dict(my_options)
if '-h' in option_lists or '--help' in option_lists:
    print('')
    print("Introduction: ")
    print("    pg_viewer is python tool to lookup pg logs in cluster environment.")
    print("    trust maybe needed for the user to login all the cluster nodes.")
    print("    If psycopg2 module have been installed, you can lookup remote logs, and use continue mode.")
    print('')
    print("Options: ")
    print("    -H, --host       : CN/GC host, default from env PGHOST or {}".format(global_db_host))
    print("    -P, --port       : CN/GC port, default from env PGPORT or {}".format(global_db_port))
    print("    -D, --database   : CN/GC database, will used to create python language and functions, default from env PGDATABASE or {}".format(global_db_name))
    print("    -U, --user       : CN/GC user, default from env PGUSER or {}".format(global_db_user))
    print("    -W, --password   : CN/GC password used with psycopg2 command mode")
    print("    -b, --begin      : Log begin time, default now() - 10 mins")
    print("    -e, --end        : Log end time, default now()")
    print("    -f, --re_filter  : Log filter with regular expression, default '{}'".format(global_re_filter))
    print("    -n, --node_filter: Only show log data of given nodes (node_name combined with comma), default '{}'".format(global_node_filter))
    print("    -s, --batch_size : Batch size in screen output and process reading, default {}".format(global_batch_size))
    print("    -a, --all        : Show all log data without suspend")
    print("    -c, --continue   : Continue to read current log data without suspend [module psycopg2 needed]")
    print("    -h, --help       : Show current help message")
    print("    -v, --version    : Show current server version")
    print('')
    print("Usage: ")
    print("    1. Running on current database node, with all env prepared")
    print("       a. Continue mode [need psycopg2 module]")
    print("          python pg_logviwer.py -c")
    print("       b. Lookup logs within a time range")
    print("          python pg_logviwer.py -b '2020-20-20 02:02:02' -e '2020-20-20 12:12:12'")
    print("       c. Show all logs in last 10 minutes without suspend")
    print("          python pg_logviwer.py -a")
    print("    2. Running on remote [need psycopg2 module]")
    print("       python pg_logviwer.py -H <host> -P <port> -D <db_name> -U <user> -W <password> -b <begin_time> -e <end_time>")
    print('')
    exit(0)
elif '-v' in option_lists or '--version' in option_lists:
    print("Tool version: {}".format(__SCRIPT_VERSION))
    exit(0)

global_db_host = option_lists['-H'] if '-H' in option_lists else option_lists['--host'] if '--host' in option_lists else global_db_host
global_db_port = option_lists['-P'] if '-P' in option_lists else option_lists['--port'] if '--port' in option_lists else global_db_port
global_db_user = option_lists['-U'] if '-U' in option_lists else option_lists['--user'] if '--user' in option_lists else global_db_user
global_db_pass = option_lists['-W'] if '-W' in option_lists else option_lists['--password'] if '--password' in option_lists else global_db_pass
global_db_name = option_lists['-D'] if '-D' in option_lists else option_lists['--database'] if '--database' in option_lists else global_db_name
global_begin_time = option_lists['-b'] if '-b' in option_lists else option_lists['--begin'] if '--begin' in option_lists else global_begin_time
global_end_time = option_lists['-e'] if '-e' in option_lists else option_lists['--end'] if '--end' in option_lists else ''
global_re_filter = option_lists['-f'] if '-f' in option_lists else option_lists['--re_filter'] if '--re_filter' in option_lists else global_re_filter
global_node_filter = option_lists['-n'] if '-n' in option_lists else option_lists['--node_filter'] if '--node_filter' in option_lists else global_node_filter
global_batch_size = option_lists['-s'] if '-s' in option_lists else option_lists['--batch_size'] if '--batch_size' in option_lists else global_batch_size
global_show_all = True if '-a' in option_lists or '--all' in option_lists else False
global_continue = True if '-c' in option_lists or '--continue' in option_lists else False


# 捕获 Ctrl + C， 更优雅的退出
def main_ctrl_c(signal_num,frame):
    global global_log_count
    global global_worker_list
    for node in global_worker_list:
        if global_worker_list[node]:
            global_worker_list[node].terminate()
            global_worker_list[node].join()
    print('\n{} line read (User request quit)'.format(global_log_count))
    sys.exit(signal_num)
signal.signal(signal.SIGINT, main_ctrl_c)


# 持续模式下，加载 psycopg2 驱动
if global_continue:
    global_show_all = True
    global_command_mode = 'psycopg2'
    import psycopg2
    from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT
# 非持续模式下，尝试加载 psycopg2 模块，加载失败则使用 psql 模式
else:
    try:
        import psycopg2
        from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT
        global_command_mode = 'psycopg2'
    except ImportError:
        print("Cannot import psycopg2, use [psql] mode")
        global_command_mode = 'psql'
        import subprocess


def get_antdb_conn(db_host=global_db_host, db_port=global_db_port, db_name=global_db_name, db_user=global_db_user, db_pass=global_db_pass):
    """
    在 psycopg2 命令模式下，连接到远程数据库，并设置当前会话参数（取消当前会话的大部分日志内容）
    :param db_host: 目标库的主机 IP
    :param db_port: 目标库的主机端口
    :param db_name: 目标库的名称
    :param db_user: 目标库的登录用户名
    :param db_pass: 目标库的登录密码
    :return: 已连接的会话对象
    """

    # 1. 连接数据库
    db_handler = psycopg2.connect(host=db_host, port=db_port, dbname=db_name, user=db_user, password=db_pass)
    db_handler.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
    antdb_cursor = db_handler.cursor()

    # 2. 设置会话参数
    antdb_cursor.execute("set log_duration = 'off'")
    antdb_cursor.execute("set log_statement = 'none'")
    antdb_cursor.execute("set log_statement_stats = 'off'")
    antdb_cursor.execute("set log_executor_stats = 'off'")
    antdb_cursor.execute("set log_error_verbosity = 'terse'")
    antdb_cursor.execute("set log_min_error_statement = 'error'")
    antdb_cursor.execute("set log_min_messages = 'warning'")
    antdb_cursor.execute("set log_parser_stats = 'off'")
    antdb_cursor.execute("set log_planner_stats = 'off'")
    antdb_cursor.execute("set log_replication_commands = 'off'")
    antdb_cursor.execute("set log_statement_stats = 'off'")

    # 3. 返回连接对象
    return antdb_cursor


def exec_os_command(cmd_string):
    """
    执行主机命令
    :param cmd_string: 需要执行的主机名列
    :return: 按行的执行结果，每一行结果都去除了尾部换行符
    """

    p = subprocess.Popen(cmd_string, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    os_output = [x.decode('utf8').strip() for x in p.stdout.readlines()]
    os_status = p.wait()
    if os_status != 0:
        print('OS Command Error:')
        print('   Command : {}'.format(cmd_string))
        print('   Status  : {}'.format(os_status))
        print('   Error   : {}'.format(os_output))
        raise Exception('OS Command Error')
    # else:
    #     print('   Command : {}'.format(cmd_string))
    #     print('   Output  : {}'.format(os_output))
    return os_output


def query_db_base(node, sql_stmt, column_count=1, host=global_db_host, port=global_db_port):
    """
    查询数据库的基础函数， 根据 global_command_mode 的不同，调用不同的方式完成数据库 SQL 的执行
    :param node: 节点名称
    :param sql_stmt: 执行的 SQL 文本
    :param column_count: SQL 返回的字段数，在 psql 模式下，需要根据这个进行每一行的字段拆分
    :param host: 查询的主机，psycopg2 命令模式下，只在第一次建连时使用，在 psql 模式下每次执行均需要使用
    :param port: 查询的端口，psycopg2 命令模式下，只在第一次建连时使用，在 psql 模式下每次执行均需要使用
    :return: 执行结果，为二维列表
    """

    db_result = []
    global global_command_mode
    global global_db_conn
    if global_command_mode == 'psycopg2':
        if node not in global_db_conn:
            global_db_conn[node] = get_antdb_conn(db_host=host, db_port=port)
        global_db_conn[node].execute(sql_stmt)
        db_result = global_db_conn[node].fetchall()
    elif global_command_mode == 'psql':
        sql_result = exec_os_command("""psql -h {} -p {} -d {} -U {} -t -A -c "{}" """.format(host, port, global_db_name, global_db_user, sql_stmt))
        db_result = [x.split('|', column_count) if column_count > 1 else [x,] for x in sql_result]
    else:
        print('Unsupport mode [{}]'.format(global_command_mode))
        sys.exit(1)

    # print('Execute SQL [{}]\nDB Result {}'.format(sql_stmt, db_result))
    return db_result


def node_queryer(node_name, db_host, db_port):
    """
    节点子进程的主体逻辑，负责各个节点的日志的查询，以及持续模式下的日志内容跟踪刷新
    :param node_name: 当前进程负责的节点名称
    :param db_host: 节点对应的数据库 IP 地址
    :param db_port: 节点对应的数据库端口
    :return: 无意义
    """

    # 获取全局参数以及数据队列
    global global_continue
    data_queue = global_queue_list[node_name]

    # 定义子进程退出的提示信息
    def node_ctrl_c(signal_num,frame):
        print('\nSub-Process of node [{}] exited by [CTRL + C]'.format(node_name))
        sys.exit(signal_num)
    signal.signal(signal.SIGINT, node_ctrl_c)

    # 定义主程序中的偏函数
    def query_db(sql_stmt, columns=1):
        return query_db_base(node_name, sql_stmt, column_count=columns, host=db_host, port=db_port)

    # 定义内部函数，按照范围读取日志文件内容
    def read_file(p_file, p_begin, p_end):
        while int(p_begin) < int(p_end):
            for l_data in query_db("select * from gvf_read_logfile('pg_log/{}', {}, {}, {}, '{}')".format(p_file, p_begin, p_end, global_batch_size, global_re_filter)):
                if l_data[0].startswith('STOP_LIMIT'):
                    p_begin = l_data[0].split(':')[1]
                    break
                data_queue.put(l_data[0])
            else:
                p_begin = p_end
        return p_begin

    # 先读取指定时段的数据
    last_read_file = ''
    last_read_pos = 0
    query_file_cmd = "select file_name, begin_position, end_position from gvf_file_range('{}')".format(global_begin_time)
    if global_end_time:
        query_file_cmd = "select file_name, begin_position, end_position from gvf_file_range('{}', '{}')".format(global_begin_time, global_end_time)
    for l_file, l_begin_pos, l_end_pos in query_db(query_file_cmd, 3):
        last_read_file = l_file
        last_read_pos = read_file(l_file, l_begin_pos, l_end_pos)

    # 再持续跟踪最新的数据
    if global_end_time or last_read_file == '':
        last_read_file, last_read_pos = query_db("select name, size from pg_ls_logdir() where name = replace(pg_current_logfile('csvlog'), 'pg_log/'::text, '')", 2)[0]
    while global_continue:
        data_queue.put('CONTINUE_BEGIN')
        is_file_read = 0
        for l_file, l_end_pos in query_db("select name, size from pg_ls_logdir() where name like 'postgresql-%.csv' and name >= '{}' order by name".format(last_read_file), 2):
            last_read_pos = last_read_pos if l_file == last_read_file else 0
            last_read_file = l_file
            if int(last_read_pos) < int(l_end_pos):
                # print('Continue_Read_File [{}] [{}] [{}]'.format(l_file, last_read_pos, l_end_pos))
                last_read_pos = read_file(l_file, last_read_pos, l_end_pos)
                is_file_read = 1
        if not is_file_read:
            time.sleep(0.2)


def get_node_data(node):
    """
    根据节点名称，获取节点队列中的数据
    :param node: 节点名称
    :return: 节点队列中的第一行数据，若 0.2 秒未获取到且处于持续模式时，返回 CONTINUE_BEGIN
    """

    while True:
        try:
            return global_queue_list[node].get(timeout=0.2)
        except Empty:
            if not global_worker_list[node].is_alive():
                global_worker_list[node].join()
                del global_worker_list[node]
                del global_queue_list[node]
                return None
            elif global_continue_status[node]:
                return 'CONTINUE_BEGIN'



# ======================================================================================================================
# 以下是脚本的逻辑主体
# ======================================================================================================================


# 定义主程序中的偏函数
def query_db(sql_stmt, columns=1):
    return query_db_base('main', sql_stmt, column_count=columns, host=global_db_host, port=global_db_port)


# 1. 检查必要的函数
# ======================================================================================================================
gvf_proc_count = query_db("select count(*) from pg_proc where proname in ('gvf_file_range', 'gvf_read_logfile')")[0][0]
if gvf_proc_count != 2:
    print("Please run [Global_Logfile.sql] script on target database before first using !!!")
    sys.exit(1)


# 2. 启动工作子进程
# ======================================================================================================================
is_cluster = query_db("select count(*) from pg_class where relname = 'pgxc_node'")[0][0]
max_node_length = 1
if is_cluster:
    node_sql_cmd = "select node_name, node_host, node_port from pgxc_node where node_type in ('C', 'D') order by node_name"
    if global_node_filter != '*':
        node_sql_cmd = "select node_name, node_host, node_port from pgxc_node where node_type in ('C', 'D') and node_name in ('{}') order by node_name".format(global_node_filter.replace(' ', "").replace(',', "','"))
    for node_name, node_host, node_port in query_db(node_sql_cmd, 3):
        global_queue_list[node_name] = Queue(maxsize=1000)
        global_continue_status[node_name] = False
        global_worker_list[node_name] = Process(target=node_queryer, args=(node_name, node_host, node_port))
        global_worker_list[node_name].start()
        max_node_length = len(node_name) if len(node_name) > max_node_length else max_node_length
else:
    global_queue_list['*'] = Queue(maxsize=1000)
    global_continue_status['*'] = False
    global_worker_list['*'] = Process(target=node_queryer, args=('*', global_db_host, global_db_port))
    global_worker_list['*'].start()


# 3. 获取各个节点的第一批数据，并进行预排序
# ======================================================================================================================
node_minimal_list = []
for node_name in list(global_queue_list.keys()):
    node_data = get_node_data(node_name)
    if node_data is not None:
        node_minimal_list.append((node_data, node_name))
node_minimal_list = sorted(node_minimal_list, key=lambda x: x[0], reverse=True)


# 4. 遍历并持续输出数据
# ======================================================================================================================
while node_minimal_list:
    # 输出最后一条日志（最小）
    # print(node_minimal_list)
    min_log, min_node = node_minimal_list.pop()
    if min_log == 'CONTINUE_BEGIN':
        global_continue_status[min_node] = True
    else:
        print(('[{:<' + str(max_node_length) + 's}] {}').format(min_node, min_log))
        global_log_count += 1

    # 补充当前输出 node 上的新日志
    next_data = get_node_data(min_node)
    if next_data is not None:
        next_pos = 0
        for (d, n) in node_minimal_list:
            if next_data < d:
                next_pos += 1
        node_minimal_list.insert(next_pos, (next_data, min_node))

    # 判断是否需要暂停输出
    if (not global_show_all) and global_log_count > 0 and global_log_count % global_batch_size == 0:
        if sys.version.startswith('2'):
            user_input = raw_input('Press enter to continue (Q/q + enter for quit) ...')
        else:
            user_input = input('Press enter to continue (Q/q + enter for quit) ...')
        if user_input.lower().startswith('q'):
            print('{} line read (User request quit)'.format(global_log_count))
            for node_name in global_worker_list.keys():
                # print("Terminal sub-process for node [{}]".format(node_name))
                global_worker_list[node_name].terminate()
                global_worker_list[node_name].join()
            exit(0)

print('{} line found'.format(global_log_count))
