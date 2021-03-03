# 配置参数说明

##### DateStyle



##### IntervalStyle

##### TimeZone
##### adb_custom_plan_tries

功能：

设置日期显示格式和默认解析格式，例如“ISO, MDY”

使用：

```
postgres=# set DateStyle='Postgres,DMY';
SET
postgres=# select current_date;         
-[ RECORD 1 ]+-----------
current_date | 10-02-2020
```

##### adb_ha_param_delimiter



##### adb_log_query



##### adb_node_type

展示节点类型：当前节点类型总共有三种，coordinator，gtm_coord，datanode

```
postgres=# show adb_node_type;
 adb_node_type 
---------------
 coordinator
(1 row)
```

##### adb_slot_enable_mvcc

需要删除此参数



##### adb_version

展示AntDB当前的版本号

```
postgres=# show adb_version;

  adb_version  
---------------

 5.0.0 72df8e6
(1 row)
```



##### adb_version_num

显示当前AntDB版本号的整数格式

```
postgres=# show adb_version_num;

 adb_version_num 
-----------------

 50000
(1 row)
```



##### agtm_host

设置Agtmcoord的IP地址



##### agtm_port

设置设置Agtmcoord的端口号



##### allow_system_table_mods

是否允许修改系统表



##### application_name



##### archive_command



##### archive_mode

当启用archive_mode时，通过设置archive_command将已完成的WAL段发送到归档存储。

除了off，disable，还有两种模式：on,always。在正常操作期间，两种模式之间没有区别，但是当设置为always的情况下,WAL archiver在存档恢复或待机模式下也被启用。在always模式下，从归档还原或流式复制流的所有文件都将被归档（再次）。archive_mode和archive_command是单独的变量，因此可以在不更改存档模式的情况下更改archive_command。此参数只能在服务器启动时设置。

当wal_level设置为minimal时，无法启用archive_mode。

##### archive_timeout

设置归档超时时间，假如设置 archive_timeout=60 ，那么每 60 s ，会触发一次 WAL 日志切换，同时触发日志归档，这里有个隐含的假设: 当前 WAL 日志中仍有未归档的 WAL 日志内容。
注：尽量不要把archive_timeout设置的很小，如果设置的很小，他会膨胀你的归档存储，因为，你强制归档的日志，即使没有写满，也会是默认的16M（假设wal日志写满的大小为16M）

##### array_nulls

控制数组输入解析器是否将未用引号界定的NULL作为数组的一个NULL元素。 默认为on表示允许向数组中输入NULL值。

##### authentication_timeout

完成服务器认证的最长时间，如果在这个时间内没有完成认证，服务器将关闭连接。



##### auto_release_connect

完成服务器认证的最长时间，如果在这个时间内没有完成认证，服务器将关闭连接。



##### autovacuum

作用：在一定条件下自动触发对 dead tuples 进行清理并对表进行分析，当update，delete的tuples数量超过 autovacuum_vacuum_scale_factor * table_size + autovacuum_vacuum_threshold 时，进行vacuum。 



##### autovacuum_analyze_scale_factor



##### autovacuum_analyze_threshold

与下文的autovacuum_analyze_scale_factor配合使用，该参数每个表可以单独设置。

##### autovacuum_freeze_max_age

触发强制freeze的事务时间点,对于数据库里面的表,不会等到到达这个限制之后才去freeze,默认情况下,在autovacuum_freeze_max_age*0.95的事务数量时候,就会开始冻结操作,也可以通过vacuum_freeze_table_age(表级别粒度)参数控制

##### autovacuum_max_workers

vacuum同时运行的进程数量

##### autovacuum_multixact_freeze_max_age

autovacuum_freeze_max_age和autovacuum_multixact_freeze_max_age：前面一个200 million,后面一个400 million。离下一次进行xid冻结的最大事务数。

##### autovacuum_naptime

两次vacuum间隔时间，默认10min。 这个naptime会被vacuum launcher分配到每个DB上。autovacuum_naptime/num of db。 

##### autovacuum_vacuum_cost_delay

与autovacuum_vacuum_cost_delay 当vacuum操作的cost超过limit,则把vacuum延后指定的时间.cost来源是vacuum_cost_limit参数默认200,

##### autovacuum_vacuum_cost_limit

autovacuum_vacuum_cost_limit 与autovacuum_vacuum_cost_delay 当vacuum操作的cost超过limit,则把vacuum延后指定的时间.cost来源是vacuum_cost_limit参数默认200,

##### autovacuum_vacuum_scale_factor

在一定条件下自动触发对 dead tuples 进行清理并对表进行分析，当update,delete的tuples数量超过 autovacuum_vacuum_scale_factor * table_size + autovacuum_vacuum_threshold 时，进行vacuum。

##### autovacuum_vacuum_threshold

在一定条件下自动触发对 dead tuples 进行清理并对表进行分析，当update,delete的tuples数量超过 autovacuum_vacuum_scale_factor * table_size + autovacuum_vacuum_threshold 时，进行vacuum。

##### autovacuum_work_mem

每个worker可使用的最大内存数

##### backend_flush_after

单位：BLCKSZ
当某backend process脏数据超过配置阈值时，触发调用OS sync_file_range，告诉os backend flush线程异步刷盘。  
从而削减os dirty page堆积。

##### backslash_quote

是否允许使用反斜线\转义单引号 \'

##### bgwriter_delay

backgroud writer进程连续两次flush数据之间的时间的间隔。默认值是200，单位是毫秒
postgresql中脏数据的写入不仅仅是由backgroud writer参数决定的，checkpoint也对脏数据的写入进行了控制。

backgroud writer进程的间隔是以毫秒计算，而checkpoint的间隔时间相对要很长。所以bgwriter更像是在checkpoint的周期内去完成脏数据的写入。所以bgwriter进程如果能够实现周期均匀数据量合适的写入数据，在减少IO的次数的同时还能够提升命中率，对checkpoint也能够减轻压力，不至于发生集中的写入操作，而造成IO使用的高值，也可以说进一步降低了对系统资源的考验。



##### bgwriter_flush_after

单位：BLCKSZ
当bgwriter process脏数据超过配置阈值时，触发调用OS sync_file_range，告诉os backend flush线程异步刷盘。  
从而削减os dirty page堆积



##### bgwriter_lru_maxpages

backgroud writer进程每次写的最多数据量，默认值是100，单位buffers。如果脏数据量小于该数值时，写操作全部由backgroud writer进程完成；反之，大于该值时，大于的部分将有server process进程完成。设置该值为0时表示禁用backgroud writer写进程，完全有server process来完成；配置为-1时表示所有脏数据都由backgroud writer来完成。(这里不包括checkpoint操作)



##### bgwriter_lru_multiplier

这个参数表示每次往磁盘写数据块的数量，当然该值必须小于bgwriter_lru_maxpages。设置太小时需要写入的脏数据量大于每次写入的数据量，这样剩余需要写入磁盘的工作需要server process进程来完成，将会降低性能；值配置太大说明写入的脏数据量多于当时所需buffer的数量，方便了后面再次申请buffer工作，同时可能出现IO的浪费。该参数的默认值是2.0。

##### block_size

显示磁盘块的大小。

##### bonjour



##### bonjour_name



##### bytea_output



##### check_function_bodies



##### checkpoint_completion_target

完成检查点所需要的时间占检查点之间总时间的目标比例，它要求系统在恰当的时间内完成检查点，不要太快也不要太慢，过快将导致过于密集的IO, 形成IO风暴影响系统的平稳运行，过慢则可能引发持续性的IO, 降低系统性能



##### checkpoint_flush_after

单位：BLCKSZ
当checkpointer process脏数据超过配置阈值时，触发调用OS sync_file_range，告诉os backend flush线程异步刷盘。  
从而削减os dirty page堆积。



##### checkpoint_timeout

表示自动触发检查点的时间间隔。增大这个参数同样会延长系统崩溃后恢复的时间

##### checkpoint_warning

系统默认值是30秒，如果checkpoints的实际发生间隔小于该参数，将会在server log中写入写入一条相关信息。可以通过设置为0禁用。

##### client_encoding

设置客户端的字符集编码

##### client_min_messages

设置发送给客户机的消息级别。

##### cluster_name



##### commit_delay

 flush wal data之前的等待的时间间隔，单位us。通过一次flush多个事物日志来提高吞吐量（如果在给定的时间间隔内同时有其它事物提交）。
 当准备提交事物的时候如果并发活跃事物数量大于commit_siblings才会应用commit_delay机制（避免无效等待，如：延迟之后只提交了自己的事物）。如果关闭了fsync，也不会采用delay机制。默认值为0（no delay）



##### commit_siblings

应用commit_delay的前提：统一时间并发活跃连接的数量。

##### config_file



##### constraint_exclusion



##### cpu_index_tuple_cost



##### cpu_operator_cost



##### cpu_tuple_cost



##### cursor_tuple_fraction



##### data_checksums



##### data_directory



##### data_directory_mode



##### data_sync_retry



##### db_user_namespace



##### deadlock_timeout

##### debug_assertions
##### debug_enable_satisfy_mvcc
##### debug_pretty_print
##### debug_print_grammar
##### debug_print_parse
##### debug_print_plan
##### debug_print_rewritten
##### default_distribute_by
##### default_statistics_target
##### default_tablespace
##### default_text_search_config
##### default_transaction_deferrable
##### default_transaction_isolation
##### default_transaction_read_only
##### default_with_oids
##### dynamic_library_path
##### dynamic_shared_memory_type
##### effective_cache_size
##### effective_io_concurrency
##### enable_aux_dml
##### enable_batch_hash
##### enable_batch_sort
##### enable_bitmapscan
##### enable_cluster_plan
##### enable_coordinator_calculate
##### enable_fast_query_shipping
##### enable_gathermerge
##### enable_hashagg
##### enable_hashjoin
##### enable_hashscan
##### enable_indexonlyscan
##### enable_indexscan
##### enable_material
##### enable_mergejoin
##### enable_nestloop
##### enable_parallel_append
##### enable_parallel_hash
##### enable_partition_pruning
##### enable_partitionwise_aggregate
##### enable_partitionwise_join
##### enable_pushdown_art
##### enable_readsql_on_slave
##### enable_readsql_on_slave_async
##### enable_remotegroup
##### enable_remotejoin
##### enable_remotelimit
##### enable_remotesort
##### enable_seqscan
##### enable_sort
##### enable_tidscan
##### enable_truncate_ident
##### escape_string_warning
##### event_source
##### exit_on_error
##### external_pid_file
##### extra_float_digits
##### force_parallel_mode
##### force_snapshot_consistent

强同步事务快照：有4个取值默认为session；
= on, gc和cn 强等待所有节点都结束事务；
= session, gc和cn 在同一session内，每次获取SnapShot前，都会等待本session的上一次事务号已经结束;
= node, 连接同一个cn，每次获取SnapShot前，都会等待上一次该节点事务号已经结束；
（后续会取消该选项）= off, gc和cn cn提交事务到GC就认为该事务以及结束，不等待GC或其他cn结束。所以本节点和其他所有cn/dn节点，SnapRcv该事务号不一定结束。

##### snapshot_sync_waittime 

在cn/dn 向GC申请或结束事务号的超时时间 

##### from_collapse_limit
##### fsync

指明数据更新时是否调用fsync将数据从os cache中刷新到磁盘。

##### full_page_writes

当设置为on的时候，pg server会在checkpoint之后页的第一次修改之时将整个页写到wal records中（wal replay从最后一个checkpoint之后开始）。

　　这是因为当向数据库写入一个页时，可能发生os奔溃，导致数据库中的这个页同时存在新旧数据，存储在wal log中的行修改记录不足以进行奔溃恢复。关闭这个参数不影响PITR。默认on

##### geqo
##### geqo_effort
##### geqo_generations
##### geqo_pool_size
##### geqo_seed
##### geqo_selection_bias
##### geqo_threshold
##### gin_fuzzy_search_limit
##### gin_pending_list_limit



##### grammar



##### hba_file



##### hot_standby

指定在recovery期间（standby一直处于这个状态），是否允许连接查询



##### hot_standby_feedback

备库是否会定期向主库通知最小活跃事务id（xmin）值，这样使得主库vacuum进程不会清理大于xmin值的事务。

##### huge_pages



##### ident_file



##### idle_in_transaction_session_timeout

空闲事务超时。终止任何已经闲置超过这个参数所指定的时间（以毫秒计）的打开事务的会话。 这使得该会话所持有的任何锁被释放，并且其所持有的连接槽可以被重用， 它也允许只对这个事务可见的元组被清理。



##### ignore_checksum_failure
##### ignore_system_indexes
##### integer_datetimes
##### jit
##### jit_above_cost
##### jit_debugging_support
##### jit_dump_bitcode
##### jit_expressions
##### jit_inline_above_cost
##### jit_optimize_above_cost
##### jit_profiling_support
##### jit_provider
##### jit_tuple_deforming
##### join_collapse_limit
##### krb_caseins_users
##### krb_server_keyfile
##### lc_collate
##### lc_ctype
##### lc_messages
##### lc_monetary
##### lc_numeric
##### lc_time
##### listen_addresses
##### lo_compat_privileges
##### local_preload_libraries
##### lock_timeout

锁等待超时。语句在试图获取表、索引、行或其他数据库对象上的锁时等到超过指定的毫秒数，该语句将被中止。不推荐在postgresql.conf中设置

##### log_autovacuum_min_duration
##### log_checkpoints

监控数据库的checkpoint 

当数据库进行一项大更新操作时，如果参数设置不当，会在日志里留下大量的告警信息，频繁的做checkpoint会导致系统变慢，不用设置都会有。
但是不会记录系统正常的checkpoint，如果你想看系统一天之类发生了多少次checkpoint，以及每次checkpoint的一些详细信息，比如buffer,sync等，就可以通过设置log_checkpoints，该参数默认值是off。

##### log_connections

用户session登陆时是否写入日志，默认off

##### log_destination

日志记录类型，默认是stderr，只记录错误输出

##### log_directory

日志路径，默认是$PGDATA/pg_log, 这个目录最好不要和数据文件的目录放在一起, 目录需要给启动postgres的操作系统用户写权限.

##### log_disconnections

用户session退出时是否写入日志，默认off

##### log_duration

log_duration设置记录SQL执行时间

##### log_error_verbosity

默认为default，verbose表示冗长的

##### log_executor_stats

报告数据库执行器的统计数据

##### log_file_mode



##### log_filename

日志名称，默认是postgresql-%Y-%m-%d_%H%M%S.log

##### log_hostname
##### log_line_prefix
##### log_lock_waits

数据库的锁通常可以在pg_locks这个系统表里找，但这只是当前的锁表/行信息，如果你想看一天内有多少个超过死锁时间的锁发生，可以在日志里设置并查看，log_lock_waits 默认是off，可以设置开启。这个可以区分SQL慢是资源紧张还是锁等待的问题。

##### log_min_duration_statement
##### log_min_error_statement
##### log_min_messages
##### log_parser_stats

记载数据库解析器的统计数据

##### log_planner_stats

报告数据库查询优化器的统计数据

##### log_replication_commands



##### log_rotation_age

保留单个文件的最大时长,默认是1d,也有1h,1min,1s,个人觉得不实用

##### log_rotation_size

保留单个文件的最大尺寸，默认是10MB

##### log_statement



##### log_statement_stats



##### log_temp_files



##### log_timezone



##### log_truncate_on_rotation

默认为off，设置为on的话，如果新建了一个同名的日志文件，则会清空原来的文件，再写入日志，而不是在后面附加。

##### logging_collector
##### maintenance_work_mem
##### max_cn_prealloc_xid_size

cn和dn预分配事务号的大小，默认为0 不预分配事务号

##### snap_receiver_timeout

cn/dn 事务分发进程和GC连接的心跳超时时间。

##### gxid_receiver_timeout

cn/dn 事务分配进程和GC连接的心跳超时时间。

##### max_connections
##### max_coordinators
##### max_datanodes
##### max_files_per_process
##### max_function_args
##### max_identifier_length
##### max_index_keys
##### max_locks_per_transaction
##### max_logical_replication_workers
##### max_parallel_maintenance_workers
##### max_parallel_workers

所有会话，在同一时刻的QUERY，并行计算最大允许开启的WORKER数

##### max_parallel_workers_per_gather

必须被设置为大于零的值。这是一种特殊情况，更加普遍的原则是所用的工作者数量不能超过max_parallel_workers_per_gather所配置的数量。 
设置单个Gather节点能够开始的工作者的最大数量。 
并行工作者会从max_worker_processes建立的进程池中取得。 
注意所要求的工作者数量在运行时可能实际无法被满足。 
如果这种事情发生， 该计划将会以比预期更少的工作者运行，这可能会不太高效。 
这个值设置为 0（默认值）将会禁用并行查询执行。 
注意并行查询可能消耗比非并行查询更多的资源， 因为每一个工作者进程时一个完全独立的进程， 它对系统产生的影响大致和一个额外的用户会话相同。 
在为这个设置选择值时， 以及配置其他控制资源利用的设置（例如work_mem）时， 应该把这个因素考虑在内。work_mem 之类的资源限制会被独立地应用于每一个工作者， 这意味着所有进程的总资源利用可能会比单个进程时高得多。 
例如， 一个使用 4 个工作者的并行查询使用的 CPU 时间、内存、I/O 带宽可能是不使用工作者时的 5 倍之多。
单条QUERY中，每个node最多允许开启的并行计算WORKER数



##### max_pool_size
##### max_pred_locks_per_page
##### max_pred_locks_per_relation
##### max_pred_locks_per_transaction
##### max_prepared_transactions
##### max_replication_slots
##### max_stack_depth
##### max_standby_archive_delay

应用当前wal segments的总时间（应用时间+等待本地冲突的sql查询的时间）。当要应用的wal信息和standby server上的sql查询冲突时，需要等待一定时间之后把sql查询cancel掉。默认值是30S，设置成-1表示一直等到sql查询执行结束，这会导致wal archive信息不断增大但是得不到应用。

##### max_standby_streaming_delay

参数意义同上，只是这个wal data来自流复制，上面的wal data是来自wal archive。
       场景举例：master发来的wal 信息是删除一个表，slave正在该表执行sql查询。

##### max_sync_workers_per_subscription



##### max_wal_senders

指定最大数量的并发连接数（简单理解为slave的数量）。由于time_wait的存在，可能需要设置的比实际使用值稍大。

##### max_wal_size
##### max_worker_processes

设置系统能够支持的后台进程的最大数量。这个参数只能在服务器启动时设置。 默认值为 8。 
在运行一个后备服务器时，你必须把这个参数设置为等于或者高于主控服务器上的值。否则， 后备服务器上可能不会允许查询。

##### min_parallel_index_scan_size



##### min_parallel_table_scan_size

启用并行查询的表的最小值

##### min_pool_size
##### min_wal_size

只要磁盘使用量低于这个值，老的wal 文件会被循环使用而不是删除。可以理解为wal日志的保留磁盘大小，在这个大小之内的文件不会被删除，后续可以直接复写，那么其磁盘空间也是一直被自己占着。

##### nls_date_format
##### nls_timestamp_format
##### nls_timestamp_tz_format
##### old_snapshot_threshold
##### operator_precedence_warning
##### parallel_leader_participation
##### parallel_setup_cost
##### parallel_tuple_cost
##### password_encryption
##### persistent_datanode_connections
##### pgxc_enable_remote_query
##### pgxc_node_name
##### pgxc_remote_tuple_cost



##### pgxcnode_cancel_delay



##### pool_release_to_idle_timeout



##### pool_remote_cmd_timeout



##### pool_time_out



##### pool_time_out



##### port



##### post_auth_delay



##### pre_auth_delay



##### quote_all_identifiers



##### random_page_cost



##### reduce_conn_cost



##### reduce_page_cost



##### reduce_scan_bucket_size



##### reduce_scan_max_buckets



##### reduce_setup_cost



##### remote_tuple_cost



##### remotetype



##### rep_max_avail_flag



##### rep_max_avail_lsn_lag



##### rep_read_archive_path



##### rep_read_archive_path_flag



##### require_replicated_table_pkey



##### restart_after_crash



##### row_security



##### search_path



##### segment_size



##### seq_page_cost



##### server_encoding

设置服务器（数据库）字符集编码。

##### server_version

显示服务器版本

##### server_version_num



##### session_preload_libraries



##### session_replication_role



##### shared_buffers

数据库服务使用的共享内存缓冲区。默认值128MB。（一般使用Mem的25%，不超过40%,因为pg还要依赖于os cache）

##### shared_preload_libraries



##### snapshot_sync_waittime



##### ssl

PostgreSQL支持使用SSL连接加密客户端/服务器通信，以提高安全性。这要求在客户端和服务器系统上都安装OpenSSL，并且在构建时启用PostgreSQL中的ssl支持（使用源码安装时的--with-openssl参数）。
ssl: 支持SSL连接。默认是关闭的。这个参数只能在服务器启动时设置。SSL通信只能通过TCP/IP连接进行。

##### ssl_ca_file



##### ssl_cert_file

ssl_cert_file:指定包含SSL服务器证书的文件的名称。默认是server.crt。相对路径相对于数据目录。
此参数只能在服务器启动时设置。

##### ssl_ciphers



##### ssl_crl_file



##### ssl_dh_params_file



##### ssl_ecdh_curve



##### ssl_key_file

ssl_key_file:指定包含SSL服务器私钥的文件的名称。默认是server.key。相对路径相对于数据目录。
此参数只能在服务器启动时设置

##### ssl_passphrase_command



##### ssl_passphrase_command_supports_reload



##### ssl_prefer_server_ciphers



##### standard_conforming_strings



##### statement_timeout

控制语句执行时长，单位是ms。超过设定值，该语句将被中止。 
不推荐在postgresql.conf中设置，如非要设置，应该设置一个较大值。

##### stats_temp_directory



##### superuser_reserved_connections



##### sync_global_xmin_time



##### synchronize_seqscans



##### synchronous_commit

指定在向事物提交指令返回success之前是否需要等待wal records写到物理磁盘。可选值on，remote_apply，remote_write，local，off。
       如果synchronous_standby_names非空(集群)，这个参数控制事物提交是否需要等待wal records被复制到standby servers。
       如果设置成on，事物提交 需要等到current synchronous standby应答已经收到事物记录切刷新到磁盘。
       如果设置成remote_apply，事物提交 需要等到current synchronous standby应答已经收到事物记录且应用到内存中。
       当设置成remote_write，事物提交需要等到current synchronous standby应答已经收到事物记录且写到了os cache中。
       local表示事物提交只需要等到本机wal records flush to disk。
       如果synchronous_standby_names为空，on，remote_apply,remote_write，local提供同样的同步级别：事物提交需要等到wal record flush to disk（由fsync来控制）

##### synchronous_standby_names

指定同步流复制的standby server，配合synchronous_commit使用，提交事物时需要收到standby server的应答之后才能完成提交，如配置项 2(slave1,slave2,slave3,slave4) 表示提交事物需要得到两个slave的应答，优先取配置中前面的slave的应答，即这里取slave1和slave2的应答。如果slave1或者slave2某个挂了，下一个接管应答。上面的slave1，slave2...指的是slave的名字，由参数项application_name设置。如果这个参数没有配置，则不会使用同步配置

##### syslog_facility



##### syslog_ident



##### syslog_sequence_numbers



##### syslog_split_messages



##### tcp_keepalives_count



##### tcp_keepalives_idle



##### tcp_keepalives_interval



##### temp_buffers



##### temp_file_limit



##### temp_tablespaces



##### timezone_abbreviations



##### trace_notify



##### trace_recovery_messages



##### trace_sort



##### track_activities

是否收集每个会话的当前正在执行的命令的统计数据，包括命令开始执行的时间。

##### track_activity_query_size



##### track_commit_timestamp

记录事物提交时间

##### track_counts

是否收集数据库活动的统计数据

##### track_functions



##### track_io_timing



##### transaction_deferrable



##### transaction_isolation





##### transaction_read_only



##### transform_null_equals



##### unix_socket_directories



##### unix_socket_group



##### unix_socket_permissions



##### update_process_title



##### upper_out_oracle_target



##### use_aux_max_times



##### use_aux_type



##### vacuum_cleanup_index_scale_factor



##### vacuum_cost_delay



##### vacuum_cost_limit

当超过此值时，vacuum会sleep。默认值为200。

##### vacuum_cost_page_dirty

当vacuum时，修改了clean的page。这说明需要额外的IO去刷脏块到磁盘。默认值为20。 

##### vacuum_cost_page_hit

vacuum时，page在buffer中命中时，所花的代价。默认值为1。

##### vacuum_cost_page_miss

vacuum时，page不在buffer中，需要从磁盘中读入时的代价默认为10。

##### vacuum_defer_cleanup_age



##### vacuum_freeze_min_age



##### vacuum_freeze_table_age



##### vacuum_multixact_freeze_min_age



##### vacuum_multixact_freeze_table_age



##### waitglobaltransaction

需要在cn/dn上都设置：本地事务以及结束，等待GC结束该事务的等待超时时间

##### wal_block_size



##### wal_buffers

wal data（写入磁盘之前存在内存中的数据量）使用的共享内存大小。默认是shared_buffers/32.不大于wal segment（一般16M）。

##### wal_compression

 设置为on时，server会压缩一个整页镜像到wal log中（当开启full_page_writes或者在base backup期间）。压缩的页镜像会在wal 回放时解压。默认off。开启会减小内存消耗，但是增加cpu消耗

##### wal_consistency_checking



##### wal_keep_segments

指定pg_xlog目录保存的wal log的最小数量

##### wal_level

指定写入到wal中的信息，默认是minimal，只写从crash中恢复或者快速shutdown需要的信息。

　　replica 是在minimal的基础上添加wal archiving需要的信息。

　　logical 增加逻辑编码需要的信息。minimal wal不包含从base backup和wal log重新构造数据库数据的信息。replica或者logical可以。老版本的参数archive或者hot_standby 在这里被映射到replica模式

##### wal_log_hints

当这个参数为on时，PostgreSQL服务器一个检查点之后页面被第一次修改期间把该磁盘页面的整个内容都写入WAL，即使对所谓的提示位做非关键修改也会这样做。默认关闭

##### wal_receiver_status_interval

指定slave向master发送replication 信息最长时间间隔，默认10S，发送的主要信息：最后一条事物日志的位置（写到os cache），最后一条flush到磁盘的事物日志，最后一条应用的事物日志。write事物日志或者flush位置改变都会触发一次发送，或者最长等到这个最大时间间隔。

##### wal_receiver_timeout

复制连接的超时时间。默认值60S。用于感知master故障。

##### wal_retrieve_retry_interval

指定slave在wal 数据源（streaming replication，local pg_xlog or wal archive）不可用时的重试等待时间。默认5S

##### wal_segment_size
##### wal_sender_timeout

指定复制流连接的超时时间，用于感知故障。默认是60S

##### wal_sync_method

强制wal 从os cache更新信息到磁盘的方法，如果fsync是关闭的，这个参数无效。
       下面open开头的是基于linux open功能函数，f开头的是基于linux sync功能函数
       Short answer seems to be that the physical write is guaranteed: open = immediately; fsync = at commit
       open_datasync
       fdatasync（linux默认选项）
       　　和fsync类似，但是只在必要的时候才将metadata写到磁盘。如：文件access time，modified time改变不需要flushing，file size改变需要写到磁盘（因为时间相关的元数据出错不影响文件读写，size出错会导致新增数据读不到）
      fsync
       　　将缓存的内核数据刷新到物理磁盘，同时刷新文件的metadata（文件属性：大小，修改更新时间等）数据到磁盘。一般文件元数据和文件不在一起，所以这里需要写两次磁盘（两次寻址）
　　fsync_writethrough
       open_sync

##### wal_writer_delay

指定flush wal的频率。每执行完一次flush就会sleep wal_writer_delay ms，除非被异步提交事物唤醒。如果距离上次flush时间不到wal_write_delay并且新产生的wal data小于wal_writer_flush_after bytes，则写wal信息只会写到os，不会刷新到磁盘。

即 将wal刷新到磁盘的条件：执行周期大于等于wal_write_delay，或者小于wal_write_delay但是新产生的wal data大小大于wal_writer_flush_after。

   wal_writer_delay默认值是200ms。   



##### wal_writer_flush_after

单位：BLCKSZ
当wal writer process脏数据超过配置阈值时，触发调用OS sync_file_range，告诉os backend flush线程异步刷盘。  
从而削减os dirty page堆积。 

##### work_mem

查询执行过程中，work_mem是内部sort（排序）操作和Hash（哈希）操作使用的。当work_mem 不够用时， 就会去使用磁盘，产生临时文件，会产生磁盘IO。
是会话级的，一个会话会分配一个work_mem，因此不宜过大。
实际使用内存是work_mem的很多倍：对于复杂查询，可能会同时运行多个排序和散列操作，且可能多个用户同时执行
排序操作用于 ORDER BY, DISTINCT 和mergejoin。 散列表用于hash join, 基于散列的聚集操作， 基于散列的 IN 子查询。
对于hash操作，哈希算子不会溢出到磁盘上，排序会溢出到磁盘

##### xc_maintenance_mode
##### xmlbinary
##### xmloption
##### zero_damaged_pages

这个参数是bool类型的，默认是off，意思是系统遇到这类因磁盘、内存等硬件引起的问题就会给出这样一份错误提示，当我们设置为on时，就可以忽略这些错误报告，并擦除掉这些损坏的数据，没受影响的数据还是正常的。
  invalid page header in block 59640 of relation base/175812/1077620; zeroing out page