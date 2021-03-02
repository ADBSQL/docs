-- This scripts contains following view's definition:
-- =============================================================================
--     ALL_CATALOG
--     ALL_COL_PRIVS
--     ALL_CONNECT_ROLE_GRANTEES
--     ALL_CONS_COLUMNS
--     ALL_CONSTRAINTS
--     ALL_DEPENDENCIES
--     ALL_IND_COLUMNS
--     ALL_IND_PARTITIONS
--     ALL_IND_STATISTICS
--     ALL_INDEX_USAGE
--     ALL_INDEXES
--     ALL_MVIEWS
--     ALL_OBJECTS
--     ALL_PART_INDEXES
--     ALL_PART_TABLES
--     ALL_PROCEDURES
--     ALL_ROLES
--     ALL_SEGMENTS
--     ALL_SEQUENCES
--     ALL_SOURCE
--     ALL_TAB_COL_STATISTICS
--     ALL_TAB_COLS
--     ALL_TAB_COLUMNS
--     ALL_TAB_COMMENTS
--     ALL_TAB_MODIFICATIONS
--     ALL_TAB_PARTITIONS
--     ALL_TAB_PRIVS
--     ALL_TAB_STATISTICS
--     ALL_TABLES
--     ALL_TRIGGER_COLS
--     ALL_TRIGGERS
--     ALL_TYPES
--     ALL_USERS
--     ALL_VIEWS
--     COLS
--     COLUMN_PRIVILEGES
--     DBA_ALL_TABLES
--     DBA_CATALOG
--     DBA_COL_PRIVS
--     DBA_CONNECT_ROLE_GRANTEES
--     DBA_CONS_COLUMNS
--     DBA_CONSTRAINTS
--     DBA_DEPENDENCIES
--     DBA_IND_COLUMNS
--     DBA_IND_PARTITIONS
--     DBA_IND_STATISTICS
--     DBA_INDEX_USAGE
--     DBA_INDEXES
--     DBA_MVIEWS
--     DBA_OBJECTS
--     DBA_PART_INDEXES
--     DBA_PART_TABLES
--     DBA_PROCEDURES
--     DBA_ROLES
--     DBA_SEGMENTS
--     DBA_SEQUENCES
--     DBA_SOURCE
--     DBA_SOURCE_ALL
--     DBA_TAB_COL_STATISTICS
--     DBA_TAB_COLS
--     DBA_TAB_COLUMNS
--     DBA_TAB_COMMENTS
--     DBA_TAB_MODIFICATIONS
--     DBA_TAB_PARTITIONS
--     DBA_TAB_PRIVS
--     DBA_TAB_STATISTICS
--     DBA_TABLES
--     DBA_TRIGGER_COLS
--     DBA_TRIGGERS
--     DBA_TYPES
--     DBA_USERS
--     DBA_VIEWS
--     DICT
--     DICTIONARY
--     IND
--     OBJ
--     ROLE_TAB_PRIVS
--     TABLE_PRIVILEGES
--     TABS
--     USER_CATALOG
--     USER_COL_PRIVS
--     USER_CONNECT_ROLE_GRANTEES
--     USER_CONS_COLUMNS
--     USER_CONSTRAINTS
--     USER_DEPENDENCIES
--     USER_IND_COLUMNS
--     USER_IND_PARTITIONS
--     USER_IND_STATISTICS
--     USER_INDEX_USAGE
--     USER_INDEXES
--     USER_MVIEWS
--     USER_OBJECTS
--     USER_PART_INDEXES
--     USER_PART_TABLES
--     USER_PROCEDURES
--     USER_SEGMENTS
--     USER_SEQUENCES
--     USER_SOURCE
--     USER_TAB_COL_STATISTICS
--     USER_TAB_COLS
--     USER_TAB_COLUMNS
--     USER_TAB_COMMENTS
--     USER_TAB_MODIFICATIONS
--     USER_TAB_PARTITIONS
--     USER_TAB_PRIVS
--     USER_TAB_STATISTICS
--     USER_TABLES
--     USER_TRIGGER_COLS
--     USER_TRIGGERS
--     USER_TYPES
--     USER_VIEWS
--     V$PARAMETER
--     V$PARAMETER_VALID_VALUES
--     V$SESSION
--     V$SPPARAMETER
-- =============================================================================

-- Set search path in current session
--     First in oracle schema,
--     if no oracle schema, then in public schema
set search_path='oracle','public';


-- Create views
DROP VIEW IF EXISTS DBA_SEQUENCES CASCADE;
CREATE OR REPLACE VIEW DBA_SEQUENCES
AS
SELECT UPPER(SCHEMANAME::text) AS SEQUENCE_OWNER
     , UPPER(SEQUENCENAME::text) AS SEQUENCE_NAME
     , MIN_VALUE
     , MAX_VALUE
     , INCREMENT_BY
     , CYCLE AS CYCLE_FLAG
     , CACHE_SIZE
     , LAST_VALUE AS LAST_NUMBER
     , UPPER(SEQUENCEOWNER::text) AS SEQUENCE_USER
     , DATA_TYPE
     , START_VALUE
  FROM pg_catalog.pg_sequences;

DROP VIEW IF EXISTS ALL_SEQUENCES CASCADE;
CREATE OR REPLACE VIEW ALL_SEQUENCES AS SELECT * FROM DBA_SEQUENCES;
DROP VIEW IF EXISTS USER_SEQUENCES CASCADE;
CREATE OR REPLACE VIEW USER_SEQUENCES AS SELECT * FROM DBA_SEQUENCES WHERE SEQUENCE_OWNER = UPPER(CURRENT_SCHEMA());


DROP VIEW IF EXISTS DBA_TAB_COLUMNS CASCADE;
CREATE OR REPLACE VIEW DBA_TAB_COLUMNS
AS
SELECT UPPER(A.relnamespace::regnamespace::text) AS OWNER
     , UPPER(A.relname) as TABLE_NAME
     , UPPER(C.attname) as COLUMN_NAME
     , UPPER(t.typname) as DATA_TYPE
     , UPPER(t.typnamespace::regnamespace::text) as DATA_TYPE_OWNER
     -- , case when c.atttypmod > 0 then c.atttypmod else COALESCE(information_schema._pg_char_max_length(information_schema._pg_truetypid(c.*, t.*), information_schema._pg_truetypmod(c.*, t.*)), information_schema._pg_numeric_precision(information_schema._pg_truetypid(c.*, t.*), information_schema._pg_truetypmod(c.*, t.*))) end AS DATA_LENGTH
     -- select oid,typname,typmodout from pg_type where typmodout <> 0;
     , translate(case when t.typmodout='bpchartypmodout'::regproc then bpchartypmodout(c.atttypmod)::text
            when t.typmodout='varchartypmodout'::regproc then varchartypmodout(c.atttypmod)::text
            when t.typmodout='timetypmodout'::regproc then timetypmodout(c.atttypmod)::text
            when t.typmodout='timestamptypmodout'::regproc then timestamptypmodout(c.atttypmod)::text
            when t.typmodout='timestamptztypmodout'::regproc then timestamptztypmodout(c.atttypmod)::text
            when t.typmodout='intervaltypmodout'::regproc then intervaltypmodout(c.atttypmod)::text
            when t.typmodout='timetztypmodout'::regproc then timetztypmodout(c.atttypmod)::text
            when t.typmodout='bittypmodout'::regproc then bittypmodout(c.atttypmod)::text
            when t.typmodout='varbittypmodout'::regproc then varbittypmodout(c.atttypmod)::text
            when t.typmodout='numerictypmodout'::regproc then numerictypmodout(c.atttypmod)::text
            when t.typmodout='varchartypmodout'::regproc then varchartypmodout(c.atttypmod)::text
            when t.typmodout='varchartypmodout'::regproc then varchartypmodout(c.atttypmod)::text
            when t.typmodout='oracle.raw_typmodout'::regproc then oracle.raw_typmodout(c.atttypmod)::text
            else null end,'()','') as DATA_LENGTH
     , information_schema._pg_char_octet_length(information_schema._pg_truetypid(c.*, t.*), information_schema._pg_truetypmod(c.*, t.*)) as DATA_LENGTH_OCTET
     , information_schema._pg_numeric_precision(information_schema._pg_truetypid(c.*, t.*), information_schema._pg_truetypmod(c.*, t.*)) as DATA_PRECISION
     , information_schema._pg_numeric_scale(information_schema._pg_truetypid(c.*, t.*), information_schema._pg_truetypmod(c.*, t.*)) as DATA_SCALE
     , CASE when C.attnotnull THEN 'N'::text ELSE 'Y'::text END AS NULLABLE
     , C.attnum as COLUMN_ID
     , length(pg_get_expr(ad.adbin, ad.adrelid)) as DEFAULT_LENGTH
     , pg_get_expr(ad.adbin, ad.adrelid) as DATA_DEFAULT
     , CASE WHEN S.n_distinct >= 0 THEN S.n_distinct ELSE ROUND(ABS(S.n_distinct * A.RELTUPLES)) END as NUM_DISTINCT
    -- LOW_VALUE                                          RAW(2000)
    -- HIGH_VALUE                                         RAW(2000)
     , S.correlation
    -- DENSITY                                            NUMBER
     , S.NULL_FRAC * A.RELTUPLES AS NUM_NULLS
    -- NUM_BUCKETS                                        NUMBER
    -- LAST_ANALYZED                                      DATE
    -- SAMPLE_SIZE                                        NUMBER
    -- CHARACTER_SET_NAME                                 VARCHAR2(44)
    -- CHAR_COL_DECL_LENGTH                               NUMBER
    -- GLOBAL_STATS                                       VARCHAR2(3)
    -- USER_STATS                                         VARCHAR2(3)
     , S.avg_width as AVG_COL_LEN
    -- CHAR_LENGTH                                        NUMBER
    -- CHAR_USED                                          VARCHAR2(1)
    -- V80_FMT_IMAGE                                      VARCHAR2(3)
    -- DATA_UPGRADED                                      VARCHAR2(3)
    -- HIDDEN_COLUMN                                      VARCHAR2(3)
    -- VIRTUAL_COLUMN                                     VARCHAR2(3)
    -- SEGMENT_COLUMN_ID                                  NUMBER
    -- INTERNAL_COLUMN_ID                        NOT NULL NUMBER
    -- HISTOGRAM                                          VARCHAR2(15)
    -- QUALIFIED_COL_NAME                                 VARCHAR2(4000)
    -- USER_GENERATED                                     VARCHAR2(3)
    -- DEFAULT_ON_NULL                                    VARCHAR2(3)
    -- IDENTITY_COLUMN                                    VARCHAR2(3)
    -- SENSITIVE_COLUMN                                   VARCHAR2(3)
    -- EVALUATION_EDITION                                 VARCHAR2(128)
    -- UNUSABLE_BEFORE                                    VARCHAR2(128)
    -- UNUSABLE_BEGINNING                                 VARCHAR2(128)
    -- COLLATION                                          VARCHAR2(100)
    -- COLLATED_COLUMN_ID                                 NUMBER
  FROM pg_catalog.pg_attribute C
  JOIN pg_catalog.pg_type t on c.atttypid = t.oid
  JOIN pg_catalog.pg_class A ON C.attrelid = A.oid
  LEFT JOIN pg_catalog.PG_STATS S ON A.relnamespace = S.schemaname::regnamespace AND A.relname = S.tablename AND C.attname = S.attname
  LEFT JOIN pg_catalog.pg_attrdef ad ON c.attrelid = ad.adrelid AND c.attnum = ad.adnum
 WHERE A.relnamespace::regnamespace::text NOT LIKE 'pg_toast%'
   AND C.attnum > 0;


DROP VIEW IF EXISTS ALL_TAB_COLUMNS CASCADE;
CREATE OR REPLACE VIEW ALL_TAB_COLUMNS AS SELECT * FROM DBA_TAB_COLUMNS;
DROP VIEW IF EXISTS USER_TAB_COLUMNS CASCADE;
CREATE OR REPLACE VIEW USER_TAB_COLUMNS AS SELECT * FROM DBA_TAB_COLUMNS WHERE OWNER  = UPPER(CURRENT_SCHEMA());
CREATE OR REPLACE VIEW DBA_TAB_COLS AS SELECT * FROM DBA_TAB_COLUMNS;
DROP VIEW IF EXISTS ALL_TAB_COLS CASCADE;
CREATE OR REPLACE VIEW ALL_TAB_COLS AS SELECT * FROM DBA_TAB_COLUMNS;
DROP VIEW IF EXISTS USER_TAB_COLS CASCADE;
CREATE OR REPLACE VIEW USER_TAB_COLS AS SELECT * FROM DBA_TAB_COLUMNS WHERE OWNER  = UPPER(CURRENT_SCHEMA());
CREATE OR REPLACE VIEW COLS AS SELECT * FROM DBA_TAB_COLUMNS WHERE OWNER  = UPPER(CURRENT_SCHEMA());


DROP VIEW IF EXISTS DBA_TAB_COL_STATISTICS CASCADE;
CREATE OR REPLACE VIEW DBA_TAB_COL_STATISTICS
AS
SELECT OWNER
     , TABLE_NAME
     , COLUMN_NAME
     , NUM_DISTINCT
    -- LOW_VALUE                                          RAW(2000)
    -- HIGH_VALUE                                         RAW(2000)
     , CORRELATION
    -- DENSITY                                            NUMBER
     , NUM_NULLS
    -- NUM_BUCKETS                                        NUMBER
    -- LAST_ANALYZED                                      DATE
    -- SAMPLE_SIZE                                        NUMBER
    -- GLOBAL_STATS                                       VARCHAR2(3)
    -- USER_STATS                                         VARCHAR2(3)
    -- NOTES                                              VARCHAR2(99)
     , AVG_COL_LEN
    -- HISTOGRAM                                          VARCHAR2(15)
    -- SCOPE                                              VARCHAR2(7)
  FROM DBA_TAB_COLUMNS;

DROP VIEW IF EXISTS ALL_TAB_COL_STATISTICS CASCADE;
CREATE OR REPLACE VIEW ALL_TAB_COL_STATISTICS AS SELECT * FROM DBA_TAB_COL_STATISTICS;
DROP VIEW IF EXISTS USER_TAB_COL_STATISTICS CASCADE;
CREATE OR REPLACE VIEW USER_TAB_COL_STATISTICS AS SELECT * FROM DBA_TAB_COL_STATISTICS WHERE OWNER  = UPPER(CURRENT_SCHEMA());


DROP VIEW IF EXISTS DBA_OBJECTS CASCADE;
CREATE OR REPLACE VIEW DBA_OBJECTS
AS
SELECT UPPER(c.relnamespace::regnamespace::text) AS owner
     , UPPER(c.relname) AS object_name
     , NULL as SUBOBJECT_NAME
     , c.oid AS OBJECT_ID
     , c.relfilenode as DATA_OBJECT_ID
     , CASE c.relkind
            WHEN 'r'::"char" THEN 'TABLE'::text
            WHEN 'v'::"char" THEN 'VIEW'::text
            WHEN 'm'::"char" THEN 'MATERIALIZED VIEW'::text
            WHEN 'i'::"char" THEN 'INDEX'::text
            -- WHEN 'I'::"char" THEN 'PARTITIONED INDEX'::text
            WHEN 'I'::"char" THEN 'INDEX'::text
            WHEN 'S'::"char" THEN 'SEQUENCE'::text
            WHEN 's'::"char" THEN 'SPECIAL'::text
            WHEN 'f'::"char" THEN 'FOREIGN TABLE'::text
            -- WHEN 'p'::"char" THEN 'PARTITIONED TABLE'::text
            WHEN 'p'::"char" THEN 'TABLE'::text
            WHEN 'c'::"char" THEN 'TYPE'::text
            WHEN 't'::"char" THEN 'TOAST'::text
            ELSE c.relkind::text
        END AS object_type
     -- CREATED                                            DATE
     -- LAST_DDL_TIME                                      DATE
     -- TIMESTAMP                                          VARCHAR2(19)
     -- STATUS                                             VARCHAR2(7)
     , case when relpersistence = 't' THEN 'Y' else 'N' end as TEMPORARY
     -- GENERATED                                          VARCHAR2(1)
     -- SECONDARY                                          VARCHAR2(1)
     -- NAMESPACE                                          NUMBER
     -- EDITION_NAME                                       VARCHAR2(128)
     -- SHARING                                            VARCHAR2(18)
     -- EDITIONABLE                                        VARCHAR2(1)
     -- ORACLE_MAINTAINED                                  VARCHAR2(1)
     -- APPLICATION                                        VARCHAR2(1)
     -- DEFAULT_COLLATION                                  VARCHAR2(100)
     -- DUPLICATED                                         VARCHAR2(1)
     -- SHARDED                                            VARCHAR2(1)
     -- CREATED_APPID                                      NUMBER
     -- CREATED_VSNID                                      NUMBER
     -- MODIFIED_APPID                                     NUMBER
     -- MODIFIED_VSNID                                     NUMBER
  FROM pg_catalog.pg_class c
 WHERE (not c.relispartition) and c.relnamespace::regnamespace::text not like 'pg_toast%'
 UNION ALL
SELECT UPPER(c.relnamespace::regnamespace::text) AS owner
     , UPPER(p.relname::text) AS object_name
     , UPPER(c.relname) as SUBOBJECT_NAME
     , c.oid AS OBJECT_ID
     , c.relfilenode as DATA_OBJECT_ID
     , CASE c.relkind
            WHEN 'r'::"char" THEN 'TABLE PARTITION'::text
            WHEN 'i'::"char" THEN 'INDEX PARTITION'::text
            ELSE c.relkind::text
        END AS object_type
     , case when c.relpersistence = 't' THEN 'Y' else 'N' end as TEMPORARY
  FROM pg_catalog.pg_class c
  JOIN pg_catalog.pg_inherits h on c.oid = h.inhrelid
  JOIN pg_catalog.pg_class p on h.inhparent = p.oid
 WHERE c.relispartition and c.relnamespace::regnamespace::text not like 'pg_toast%'
 UNION ALL
SELECT UPPER(p.pronamespace::regnamespace::text) AS owner
     , UPPER(p.proname) AS object_name
     , null as sub_object_name
     , min(p.OID) as OBJECT_ID
     , null as DATA_OBJECT_ID
     , CASE WHEN p.prorettype = 'trigger'::regtype::oid THEN 'TRIGGER'::text
            ELSE (case prokind when 'p' then 'PROCEDURE' else 'FUNCTION' end)
       END AS object_type
     , 'N' as temporary
  FROM pg_catalog.pg_proc p
 WHERE pg_function_is_visible(p.oid)
 group by UPPER(p.pronamespace::regnamespace::text)
        , UPPER(p.proname)
        , CASE WHEN p.prorettype = 'trigger'::regtype::oid THEN 'TRIGGER'::text
               ELSE (case prokind when 'p' then 'PROCEDURE' else 'FUNCTION' end)
          END;

DROP VIEW IF EXISTS ALL_OBJECTS CASCADE;
CREATE OR REPLACE VIEW ALL_OBJECTS AS SELECT * FROM DBA_OBJECTS;
DROP VIEW IF EXISTS USER_OBJECTS CASCADE;
CREATE OR REPLACE VIEW USER_OBJECTS AS SELECT * FROM DBA_OBJECTS WHERE OWNER  = UPPER(CURRENT_SCHEMA());
DROP VIEW IF EXISTS OBJ CASCADE;
CREATE OR REPLACE VIEW OBJ AS SELECT * FROM DBA_OBJECTS WHERE OWNER  = UPPER(CURRENT_SCHEMA());


DROP VIEW IF EXISTS DBA_CATALOG CASCADE;
CREATE OR REPLACE VIEW DBA_CATALOG
AS
SELECT UPPER(c.relnamespace::regnamespace::text) AS owner
     , UPPER(c.relname) AS TABLE_NAME
     , CASE c.relkind
            WHEN 'r'::"char" THEN 'TABLE'::text
            WHEN 'v'::"char" THEN 'VIEW'::text
            WHEN 'm'::"char" THEN 'MATERIALIZED VIEW'::text
            WHEN 'i'::"char" THEN 'INDEX'::text
            WHEN 'S'::"char" THEN 'SEQUENCE'::text
            WHEN 's'::"char" THEN 'SPECIAL'::text
            WHEN 'f'::"char" THEN 'FOREIGN TABLE'::text
            WHEN 'p'::"char" THEN 'PARTITIONED TABLE'::text
            WHEN 'c'::"char" THEN 'TYPE'::text
            WHEN 't'::"char" THEN 'TOAST'::text
            ELSE UPPER(c.relkind::text)
        END AS TABLE_TYPE
  FROM pg_catalog.pg_class c
 WHERE relkind in ('r', 'v', 'm', 's');

DROP VIEW IF EXISTS ALL_CATALOG CASCADE;
CREATE OR REPLACE VIEW ALL_CATALOG AS SELECT * FROM DBA_CATALOG;
DROP VIEW IF EXISTS USER_CATALOG CASCADE;
CREATE OR REPLACE VIEW USER_CATALOG AS SELECT * FROM DBA_CATALOG WHERE OWNER  = UPPER(CURRENT_SCHEMA());


DROP VIEW IF EXISTS DICTIONARY CASCADE;
CREATE OR REPLACE VIEW DICTIONARY
AS
SELECT UPPER(N.NSPNAME) AS OWNER
     , UPPER(C.RELNAME) AS TABLE_NAME
     , d.description as COMMENTS
  FROM pg_catalog.pg_class c
  JOIN pg_catalog.pg_namespace n on c.relnamespace  = n.oid
  LEFT JOIN pg_catalog.pg_description d on c.oid = d.objoid and d.objsubid = 0 and d.classoid = 'pg_class'::regclass::oid
 WHERE c.relkind in ('r', 'v', 'm')
   and n.nspname in ('pg_catalog', 'information_schema', 'oracle');

DROP VIEW IF EXISTS DICT;
CREATE OR REPLACE VIEW DICT AS SELECT * FROM DICTIONARY;


DROP VIEW IF EXISTS DBA_DEPENDENCIES CASCADE;
CREATE OR REPLACE VIEW DBA_DEPENDENCIES
AS
with all_obj_rewrite as (select object_id, owner, coalesce(subobject_name, object_Name) as object_Name, object_type FROM dba_objects
                          union all
                         select r.oid as object_Id, UPPER(c.relnamespace::regnamespace::text) as owner, UPPER(relname) as object_Name, 'VIEW' as object_type
                           FROM pg_catalog.pg_rewrite r
                           JOIN pg_catalog.pg_class c on r.ev_class = c.oid
                          WHERE c.relnamespace::regnamespace::text not like 'pg_toast%')
SELECT distinct c.OWNER
     , c.object_name as NAME
     , c.object_type as TYPE
     , cr.OWNER as REFERENCED_OWNER
     , cr.object_name as REFERENCED_NAME
     , cr.object_type as REFERENCED_TYPE
     -- REFERENCED_LINK_NAME
     , case d.deptype when 'n' then 'NORMAL' when 'a' then 'AUTO' when 'i' then 'INTERNAL' when 'I' then 'INTERNAL_AUTO' when 'e' then 'EXTENSION' when 'x' then 'AUTO_EXTENSION' when 'p' then 'PIN' else UPPER(d.deptype::text) end as DEPENDENCY_TYPE
  FROM pg_catalog.pg_depend d
  join all_obj_rewrite c on d.objid = c.object_id
  join all_obj_rewrite cr on d.refobjid = cr.object_id
 WHERE d.classid in ('pg_class'::regclass::oid, 'pg_proc'::regclass::oid, 'pg_rewrite'::regclass::oid)
   and d.objsubid = 0
   and (c.OWNER != cr.OWNER or c.object_name != cr.object_name);

DROP VIEW IF EXISTS ALL_DEPENDENCIES CASCADE;
CREATE OR REPLACE VIEW ALL_DEPENDENCIES AS SELECT * FROM DBA_DEPENDENCIES;
DROP VIEW IF EXISTS USER_DEPENDENCIES CASCADE;
CREATE OR REPLACE VIEW USER_DEPENDENCIES AS SELECT * FROM DBA_DEPENDENCIES WHERE OWNER  = UPPER(CURRENT_SCHEMA());


DROP VIEW IF EXISTS DBA_SEGMENTS CASCADE;
CREATE OR REPLACE VIEW DBA_SEGMENTS
AS
SELECT o.owner
     , o.object_name as SEGMENT_NAME
     , o.subobject_name as PARTITION_NAME
     , o.object_type as SEGMENT_TYPE
     -- SEGMENT_SUBTYPE                                    VARCHAR2(10)
     , coalesce(UPPER(t.spcname), 'DEFAULT') as TABLESPACE_NAME
     -- HEADER_FILE                                        NUMBER
     -- HEADER_BLOCK                                       NUMBER
     , pg_relation_size(o.object_id) as bytes
     , pg_relation_size(o.object_id)/b.block_size as blocks
     -- EXTENTS                                            NUMBER
     -- INITIAL_EXTENT                                     NUMBER
     -- NEXT_EXTENT                                        NUMBER
     -- MIN_EXTENTS                                        NUMBER
     -- MAX_EXTENTS                                        NUMBER
     -- MAX_SIZE                                           NUMBER
     -- RETENTION                                          VARCHAR2(7)
     -- MINRETENTION                                       NUMBER
     -- PCT_INCREASE                                       NUMBER
     -- FREELISTS                                          NUMBER
     -- FREELIST_GROUPS                                    NUMBER
     -- RELATIVE_FNO                                       NUMBER
     -- BUFFER_POOL                                        VARCHAR2(7)
     -- FLASH_CACHE                                        VARCHAR2(7)
     -- CELL_FLASH_CACHE                                   VARCHAR2(7)
     -- INMEMORY                                           VARCHAR2(8)
     -- INMEMORY_PRIORITY                                  VARCHAR2(8)
     -- INMEMORY_DISTRIBUTE                                VARCHAR2(15)
     -- INMEMORY_DUPLICATE                                 VARCHAR2(13)
     -- INMEMORY_COMPRESSION                               VARCHAR2(17)
     -- CELLMEMORY                                         VARCHAR2(24)
  FROM DBA_OBJECTS o
  join (select setting::bigint as block_size FROM pg_catalog.pg_settings WHERE name = 'block_size') b on 1=1
  join pg_catalog.pg_class c on o.object_id = c.oid
  left join pg_catalog.pg_tablespace t on c.reltablespace = t.oid
 WHERE o.DATA_OBJECT_ID is not null;

DROP VIEW IF EXISTS ALL_SEGMENTS CASCADE;
CREATE OR REPLACE VIEW ALL_SEGMENTS AS SELECT * FROM DBA_SEGMENTS;
DROP VIEW IF EXISTS USER_SEGMENTS CASCADE;
CREATE OR REPLACE VIEW USER_SEGMENTS AS SELECT * FROM DBA_SEGMENTS WHERE OWNER  = UPPER(CURRENT_SCHEMA());


DROP VIEW IF EXISTS DBA_SOURCE_ALL CASCADE;
CREATE OR REPLACE VIEW DBA_SOURCE_ALL
AS
SELECT UPPER(pronamespace::regnamespace::text) as OWNER
     , UPPER(proname::text) as NAME
     , CASE WHEN prorettype = 'trigger'::regtype::oid THEN 'TRIGGER'::text
            ELSE (case prokind when 'p' then 'PROCEDURE' else 'FUNCTION' end)
       END AS TYPE
     , 0 as LINE
     , prosrc as TEXT
     -- ORIGIN_CON_ID                                      NUMBER
  FROM pg_catalog.pg_proc
 WHERE prolang not in (select oid FROM pg_catalog.pg_language WHERE lanname in ('internal', 'c'));


DROP VIEW IF EXISTS DBA_SOURCE CASCADE;
CREATE OR REPLACE VIEW DBA_SOURCE
AS
with recursive
ta as (select UPPER(pronamespace::regnamespace::text) as OWNER
            , UPPER(proname::text) || case when oidvectortypes(PROARGTYPES) = '' then '' else ' ('||oidvectortypes(PROARGTYPES)||')' end as NAME
            , CASE WHEN prorettype = 'trigger'::regtype::oid THEN 'TRIGGER'::text ELSE (case prokind when 'p' then 'PROCEDURE' else 'FUNCTION' end) END AS TYPE
            , prosrc as TEXT
            , length(prosrc) - length(replace(prosrc, chr(10), '')) + 1 as lines
         FROM pg_catalog.pg_proc
        WHERE prolang not in (select oid FROM pg_catalog.pg_language WHERE lanname in ('internal', 'c'))
      ),
t_line as (select owner, name, type, text, 1 as line_id, lines FROM ta
            union all
           select owner, name, type, text, 1 + line_id as line_id, lines FROM t_line WHERE 1 + line_id <= lines)
select owner, name, type, line_id as line, oracle.substr(text, p1 + 1, p2-p1-1) as text
  FROM (select owner, name, type, line_id, lines, text
             , case line_id when 1 then 0 else oracle.instr(text, chr(10), 1, line_id - 1) end as p1
             , case oracle.instr(text, chr(10), 1, line_id) when 0 then length(text) else oracle.instr(text, chr(10), 1, line_id) end as p2
          FROM t_line) as x
 order by owner, name, line_id;

DROP VIEW IF EXISTS ALL_SOURCE CASCADE;
CREATE OR REPLACE VIEW ALL_SOURCE AS SELECT * FROM DBA_SOURCE;
DROP VIEW IF EXISTS USER_SOURCE CASCADE;
CREATE OR REPLACE VIEW USER_SOURCE AS SELECT * FROM DBA_SOURCE WHERE OWNER = UPPER(CURRENT_SCHEMA());


DROP VIEW IF EXISTS DBA_PROCEDURES CASCADE;
CREATE OR REPLACE VIEW DBA_PROCEDURES
AS
SELECT UPPER(pronamespace::regnamespace::text) as OWNER
     , UPPER(proname::text) as OBJECT_NAME
     -- PROCEDURE_NAME                       VARCHAR2(128)
     , oid as OBJECT_ID
     -- SUBPROGRAM_ID                        NUMBER
     -- OVERLOAD                             VARCHAR2(40)
     , CASE WHEN prorettype = 'trigger'::regtype::oid THEN 'TRIGGER'::text
            ELSE (case prokind when 'p' then 'PROCEDURE' else 'FUNCTION' end)
       END AS OBJECT_TYPE
     , case prokind when 'a' then 'YES' else 'NO' end as AGGREGATE
     -- PIPELINED                            VARCHAR2(3)
     -- IMPLTYPEOWNER                        VARCHAR2(128)
     -- IMPLTYPENAME                         VARCHAR2(128)
     , case proparallel when 'u' then 'NO' else 'YES' end as PARALLEL
     -- INTERFACE                            VARCHAR2(3)
     , case provolatile when 'v' then 'NO' else 'YES 'end as DETERMINISTIC
     -- AUTHID                               VARCHAR2(12)
     -- RESULT_CACHE                         VARCHAR2(3)
     -- ORIGIN_CON_ID                        NUMBER
     -- POLYMORPHIC                          VARCHAR2(5)
   FROM pg_catalog.pg_proc
 WHERE prolang not in (select oid FROM pg_catalog.pg_language WHERE lanname in ('internal', 'c'));

DROP VIEW IF EXISTS ALL_PROCEDURES CASCADE;
CREATE OR REPLACE VIEW ALL_PROCEDURES AS SELECT * FROM DBA_PROCEDURES;
DROP VIEW IF EXISTS USER_PROCEDURES CASCADE;
CREATE OR REPLACE VIEW USER_PROCEDURES AS SELECT * FROM DBA_PROCEDURES WHERE OWNER = UPPER(CURRENT_SCHEMA());


DROP VIEW IF EXISTS DBA_TRIGGERS CASCADE;
CREATE OR REPLACE VIEW DBA_TRIGGERS
AS
SELECT UPPER(it.trigger_schema) as OWNER
     , UPPER(it.trigger_name) as TRIGGER_NAME
     , UPPER(it.action_timing||' '||action_orientation) as TRIGGER_TYPE
     , UPPER(it.event_manipulation) as TRIGGERING_EVENT
     , UPPER(it.event_object_schema) as TABLE_OWNER
     , 'TABLE' As BASE_OBJECT_TYPE
     , UPPER(it.event_object_table) as TABLE_NAME
     -- COLUMN_NAME                   VARCHAR2(4000)
     , 'REFERENCING NEW AS '||coalesce(UPPER(it.action_reference_new_table), 'NEW')||' OLD AS '||coalesce(UPPER(it.action_reference_old_table), 'OLD') as REFERENCING_NAMES
     , it.action_condition as WHEN_CLAUSE
     , case ct.tgenabled when 'D' then 'DISABLED' else 'ENABLED' end as STATUS
     -- DESCRIPTION                   VARCHAR2(4000)
     , 'PL/SQL' as ACTION_TYPE
     , it.action_statement as TRIGGER_BODY
     -- CROSSEDITION                  VARCHAR2(7)
     , case when it.action_orientation = 'STATEMENT' and it.action_timing = 'BEFORE' then 'YES' else 'NO' end as BEFORE_STATEMENT
     , case when it.action_orientation = 'ROW' and it.action_timing = 'BEFORE' then 'YES' else 'NO' end as BEFORE_ROW
     , case when it.action_orientation = 'ROW' and it.action_timing = 'AFTER' then 'YES' else 'NO' end as AFTER_ROW
     , case when it.action_orientation = 'STATEMENT' and it.action_timing = 'AFTER' then 'YES' else 'NO' end as AFTER_STATEMENT
     , case when it.action_orientation = 'ROW' and it.action_timing = 'INSTEAD OF' then 'YES' else 'NO' end as INSTEAD_OF_ROW
     -- FIRE_ONCE                     VARCHAR2(3)
     -- APPLY_SERVER_ONLY             VARCHAR2(3)
  FROM information_schema.triggers it
  join pg_catalog.pg_trigger ct on it.trigger_name = ct.tgname
  join pg_catalog.pg_class pc on ct.tgrelid = pc.oid and it.trigger_schema::text = pc.relnamespace::regnamespace::text
 WHERE it.trigger_catalog = current_database();

DROP VIEW IF EXISTS ALL_TRIGGERS CASCADE;
CREATE OR REPLACE VIEW ALL_TRIGGERS AS SELECT * FROM DBA_TRIGGERS;
DROP VIEW IF EXISTS USER_TRIGGERS CASCADE;
CREATE OR REPLACE VIEW USER_TRIGGERS AS SELECT * FROM DBA_TRIGGERS WHERE OWNER = UPPER(CURRENT_SCHEMA());


DROP VIEW IF EXISTS DBA_TRIGGER_COLS CASCADE;
CREATE OR REPLACE VIEW DBA_TRIGGER_COLS
AS
SELECT UPPER(trigger_schema::text) as TRIGGER_OWNER
     , UPPER(trigger_name::text) as TRIGGER_NAME
     , UPPER(event_object_schema::text) as TABLE_OWNER
     , UPPER(event_object_table::text) as TABLE_NAME
     , UPPER(event_object_column::text) as COLUMN_NAME
     -- COLUMN_LIST                                                                                                               VARCHAR2(3)
     -- COLUMN_USAGE                                                                                                              VARCHAR2(17)
  FROM information_schema.triggered_update_columns
 WHERE trigger_catalog = current_database();

DROP VIEW IF EXISTS ALL_TRIGGER_COLS CASCADE;
CREATE OR REPLACE VIEW ALL_TRIGGER_COLS AS SELECT * FROM DBA_TRIGGER_COLS;
DROP VIEW IF EXISTS USER_TRIGGER_COLS CASCADE;
CREATE OR REPLACE VIEW USER_TRIGGER_COLS AS SELECT * FROM DBA_TRIGGER_COLS WHERE TRIGGER_OWNER = UPPER(CURRENT_SCHEMA());


DROP VIEW IF EXISTS DBA_TYPES CASCADE;
CREATE OR REPLACE VIEW DBA_TYPES
AS
SELECT UPPER(typnamespace::regnamespace::text) as OWNER
     , UPPER(typname::text) as TYPE_NAME
     , OID as TYPE_OID
     , case typtype when 'b' then 'BASE' when 'c' then 'COMPOSITE' when 'd' then 'DOMAIN' when 'e'  then 'ENUM' when 'p' then 'PSEUDO' when 'r' then 'RANGE' else UPPER(typtype::text) end as TYPECODE
     -- , ATTRIBUTES
     -- , METHODS
     , case when typisdefined then 'YES' else 'NO' end as PREDEFINED
     -- , INCOMPLETE
     -- , FINAL
     -- , INSTANTIABLE
     -- , PERSISTABLE
     -- , SUPERTYPE_OWNER
     -- , SUPERTYPE_NAME
     -- , LOCAL_ATTRIBUTES
     -- , LOCAL_METHODS
     -- , TYPEID
  FROM pg_catalog.pg_type
 WHERE typtype != 'b'
   and typname not in (select relname FROM pg_catalog.pg_class WHERE relkind in ('r', 't', 'v', 'p'));

DROP VIEW IF EXISTS ALL_TYPES CASCADE;
CREATE OR REPLACE VIEW ALL_TYPES AS SELECT * FROM DBA_TYPES;
DROP VIEW IF EXISTS USER_TYPES CASCADE;
CREATE OR REPLACE VIEW USER_TYPES AS SELECT * FROM DBA_TYPES WHERE OWNER = UPPER(CURRENT_SCHEMA());


DROP VIEW IF EXISTS DBA_CONSTRAINTS CASCADE;
CREATE OR REPLACE VIEW DBA_CONSTRAINTS
AS
SELECT UPPER(cons.connamespace::regnamespace::text) as OWNER
     , UPPER(cons.conname) as CONSTRAINT_NAME
     , UPPER(cons.contype::text) as CONSTRAINT_TYPE
     , UPPER(cls_r.relname::text) as TABLE_NAME
     -- SEARCH_CONDITION         LONG
     -- SEARCH_CONDITION_VC      VARCHAR2(4000)
     , UPPER(cls_f.relnamespace::regnamespace::text) as R_OWNER
     , UPPER(cls_f.relname::text) as R_TABLE_NAME
     -- R_CONSTRAINT_NAME        VARCHAR2(128)
     , case cons.confdeltype when 'a' then 'NO ACTION' when 'r' then 'RESTRICT' when 'c' then 'CASCADE' when 'n' then 'SET NULL' when 'd' then 'SET DEFAULT' else UPPER(confdeltype::text) end as DELETE_RULE
     , case when cons.convalidated then 'ENABLED' else 'DISABLED' end as STATUS
     , case when cons.condeferrable then 'DEFERRABLE' else 'NOT DEFERRABLE' end as DEFERRABLE
     , case when cons.condeferred then 'DEFERRED' else 'IMMEDIATE' end as DEFERRED
     , case when cons.convalidated then 'VALIDATED' else 'NOT VALIDATED' end as VALIDATED
     -- GENERATED                VARCHAR2(14)
     -- BAD                      VARCHAR2(3)
     -- RELY                     VARCHAR2(4)
     -- LAST_CHANGE              DATE
     , UPPER(cls_i.relnamespace::regnamespace::text) as INDEX_OWNER
     , UPPER(cls_i.relname::text) as INDEX_NAME
     , case when cons.convalidated then 'VALIDATED' else 'NOT VALIDATED' end as INVALID
     -- VIEW_RELATED             VARCHAR2(14)
     -- ORIGIN_CON_ID            NUMBER
  FROM pg_catalog.pg_constraint cons
  JOIN pg_catalog.pg_class cls_r on cons.conrelid = cls_r.oid
  LEFT JOIN pg_catalog.pg_class cls_f on cons.confrelid = cls_f.oid
  LEFT JOIN pg_catalog.pg_class cls_i on cons.conindid = cls_i.oid
 WHERE cons.connamespace::regnamespace::text not like 'pg_toast%';

DROP VIEW IF EXISTS ALL_CONSTRAINTS CASCADE;
CREATE OR REPLACE VIEW ALL_CONSTRAINTS AS SELECT * FROM DBA_CONSTRAINTS;
DROP VIEW IF EXISTS USER_CONSTRAINTS CASCADE;
CREATE OR REPLACE VIEW USER_CONSTRAINTS AS SELECT * FROM DBA_CONSTRAINTS WHERE OWNER = UPPER(CURRENT_SCHEMA());


DROP VIEW IF EXISTS DBA_CONS_COLUMNS CASCADE;
CREATE OR REPLACE VIEW DBA_CONS_COLUMNS
AS
SELECT c.OWNER
     , c.CONSTRAINT_NAME
     , c.TABLE_NAME
     , UPPER(a.attname::text) as COLUMN_NAME
     , a.attnum as POSITION
  FROM (select UPPER(ns.nspname::text) as OWNER
             , UPPER(cn.conname::text) as CONSTRAINT_NAME
             , UPPER(cl.relname) as TABLE_NAME
             , unnest(cn.conkey) as column_Id
             , cn.conrelid as table_oid
          FROM pg_catalog.pg_constraint as cn
          join pg_catalog.pg_class as cl on cn.conrelid = cl.oid
          join pg_catalog.pg_namespace as ns on cn.connamespace = ns.oid
         WHERE ns.nspname::text not like 'pg_toast%') as c
  JOIN pg_catalog.pg_attribute a on c.table_oid = a.attrelid and c.column_Id = a.attnum;

DROP VIEW IF EXISTS ALL_CONS_COLUMNS CASCADE;
CREATE OR REPLACE VIEW ALL_CONS_COLUMNS AS SELECT * FROM DBA_CONS_COLUMNS;
DROP VIEW IF EXISTS USER_CONS_COLUMNS CASCADE;
CREATE OR REPLACE VIEW USER_CONS_COLUMNS AS SELECT * FROM DBA_CONS_COLUMNS WHERE OWNER = UPPER(CURRENT_SCHEMA());


DROP VIEW IF EXISTS DBA_VIEWS CASCADE;
CREATE OR REPLACE VIEW DBA_VIEWS
AS
SELECT UPPER(schemaname) as OWNER
     , UPPER(viewname) as VIEW_NAME
     , length(definition) as TEXT_LENGTH
     , definition as TEXT
     , definition as TEXT_VC
     -- TYPE_TEXT_LENGTH             NUMBER
     -- TYPE_TEXT                    VARCHAR2(4000)
     -- OID_TEXT_LENGTH              NUMBER
     -- OID_TEXT                     VARCHAR2(4000)
     -- VIEW_TYPE_OWNER              VARCHAR2(128)
     -- VIEW_TYPE                    VARCHAR2(128)
     -- SUPERVIEW_NAME               VARCHAR2(128)
     -- EDITIONING_VIEW              VARCHAR2(1)
     -- READ_ONLY                    VARCHAR2(1)
     -- CONTAINER_DATA               VARCHAR2(1)
     -- BEQUEATH                     VARCHAR2(12)
     -- ORIGIN_CON_ID                NUMBER
     -- DEFAULT_COLLATION            VARCHAR2(100)
     -- CONTAINERS_DEFAULT           VARCHAR2(3)
     -- CONTAINER_MAP                VARCHAR2(3)
     -- EXTENDED_DATA_LINK           VARCHAR2(3)
     -- EXTENDED_DATA_LINK_MAP       VARCHAR2(3)
     -- HAS_SENSITIVE_COLUMN         VARCHAR2(3)
     -- ADMIT_NULL                   VARCHAR2(3)
     -- PDB_LOCAL_ONLY               VARCHAR2(3)
  FROM pg_catalog.pg_views;

DROP VIEW IF EXISTS ALL_VIEWS CASCADE;
CREATE OR REPLACE VIEW ALL_VIEWS AS SELECT * FROM DBA_VIEWS;
DROP VIEW IF EXISTS USER_VIEWS CASCADE;
CREATE OR REPLACE VIEW USER_VIEWS AS SELECT * FROM DBA_VIEWS WHERE OWNER = UPPER(CURRENT_SCHEMA());


DROP VIEW IF EXISTS DBA_TABLES CASCADE;
CREATE OR REPLACE VIEW DBA_TABLES
AS
SELECT UPPER(n.nspname::text) as OWNER
     , UPPER(c.relname::text) as TABLE_NAME
     , coalesce(UPPER(t.spcname::text), 'DEFAULT') as TABLESPACE_NAME
     -- CLUSTER_NAME                               VARCHAR2(128)
     -- IOT_NAME                                   VARCHAR2(128)
     -- STATUS                                     VARCHAR2(8)
     -- PCT_FREE                                   NUMBER
     -- PCT_USED                                   NUMBER
     -- INI_TRANS                                  NUMBER
     -- MAX_TRANS                                  NUMBER
     -- INITIAL_EXTENT                             NUMBER
     -- NEXT_EXTENT                                NUMBER
     -- MIN_EXTENTS                                NUMBER
     -- MAX_EXTENTS                                NUMBER
     -- PCT_INCREASE                               NUMBER
     -- FREELISTS                                  NUMBER
     -- FREELIST_GROUPS                            NUMBER
     , case c.relpersistence when 'p' then 'YES' else 'NO' end as LOGGING
     -- BACKED_UP                                  VARCHAR2(1)
     , c.reltuples as NUM_ROWS
     , c.relpages as BLOCKS
     -- EMPTY_BLOCKS                               NUMBER
     -- AVG_SPACE                                  NUMBER
     -- CHAIN_CNT                                  NUMBER
     , s.stawidth as AVG_ROW_LEN
     -- AVG_SPACE_FREELIST_BLOCKS                  NUMBER
     -- NUM_FREELIST_BLOCKS                        NUMBER
     -- DEGREE                                     VARCHAR2(10)
     -- INSTANCES                                  VARCHAR2(10)
     -- CACHE                                      VARCHAR2(5)
     -- TABLE_LOCK                                 VARCHAR2(8)
     -- SAMPLE_SIZE                                NUMBER
     , coalesce(pg_stat_get_last_analyze_time(c.oid), pg_stat_get_last_autoanalyze_time(c.oid)) as LAST_ANALYZED
     , case c.relkind when 'p' then 'YES' else 'NO' end as PARTITIONED
     -- IOT_TYPE                                   VARCHAR2(12)
     , case c.relpersistence when 't' then 'YES' else 'NO' end as TEMPORARY
     -- SECONDARY                                  VARCHAR2(1)
     -- NESTED                                     VARCHAR2(3)
     -- BUFFER_POOL                                VARCHAR2(7)
     -- FLASH_CACHE                                VARCHAR2(7)
     -- CELL_FLASH_CACHE                           VARCHAR2(7)
     -- ROW_MOVEMENT                               VARCHAR2(8)
     -- GLOBAL_STATS                               VARCHAR2(3)
     -- USER_STATS                                 VARCHAR2(3)
     -- DURATION                                   VARCHAR2(15)
     -- SKIP_CORRUPT                               VARCHAR2(8)
     -- MONITORING                                 VARCHAR2(3)
     -- CLUSTER_OWNER                              VARCHAR2(128)
     -- DEPENDENCIES                               VARCHAR2(8)
     -- COMPRESSION                                VARCHAR2(8)
     -- COMPRESS_FOR                               VARCHAR2(30)
     -- DROPPED                                    VARCHAR2(3)
     -- READ_ONLY                                  VARCHAR2(3)
     -- SEGMENT_CREATED                            VARCHAR2(3)
     -- RESULT_CACHE                               VARCHAR2(7)
     -- CLUSTERING                                 VARCHAR2(3)
     -- ACTIVITY_TRACKING                          VARCHAR2(23)
     -- DML_TIMESTAMP                              VARCHAR2(25)
     -- HAS_IDENTITY                               VARCHAR2(3)
     -- CONTAINER_DATA                             VARCHAR2(3)
     -- INMEMORY                                   VARCHAR2(8)
     -- INMEMORY_PRIORITY                          VARCHAR2(8)
     -- INMEMORY_DISTRIBUTE                        VARCHAR2(15)
     -- INMEMORY_COMPRESSION                       VARCHAR2(17)
     -- INMEMORY_DUPLICATE                         VARCHAR2(13)
     -- DEFAULT_COLLATION                          VARCHAR2(100)
     -- DUPLICATED                                 VARCHAR2(1)
     -- SHARDED                                    VARCHAR2(1)
     -- EXTERNAL                                   VARCHAR2(3)
     -- HYBRID                                     VARCHAR2(3)
     -- CELLMEMORY                                 VARCHAR2(24)
     -- CONTAINERS_DEFAULT                         VARCHAR2(3)
     -- CONTAINER_MAP                              VARCHAR2(3)
     -- EXTENDED_DATA_LINK                         VARCHAR2(3)
     -- EXTENDED_DATA_LINK_MAP                     VARCHAR2(3)
     -- INMEMORY_SERVICE                           VARCHAR2(12)
     -- INMEMORY_SERVICE_NAME                      VARCHAR2(1000)
     -- CONTAINER_MAP_OBJECT                       VARCHAR2(3)
     -- MEMOPTIMIZE_READ                           VARCHAR2(8)
     -- MEMOPTIMIZE_WRITE                          VARCHAR2(8)
     -- HAS_SENSITIVE_COLUMN                       VARCHAR2(3)
     -- ADMIT_NULL                                 VARCHAR2(3)
     -- DATA_LINK_DML_ENABLED                      VARCHAR2(3)
     -- LOGICAL_REPLICATION                        VARCHAR2(8)
  FROM pg_catalog.pg_class c
  join pg_catalog.pg_namespace n on c.relnamespace = n.oid
  left join pg_catalog.pg_tablespace t on c.reltablespace = t.oid
  left join (select starelid, sum(stawidth) as stawidth FROM pg_catalog.pg_statistic group by starelid) s on c.oid = s.starelid
 WHERE c.relkind in ('r', 'p') and n.nspname::text not like 'pg_toast%';

CREATE OR REPLACE view DBA_ALL_TABLES AS SELECT * FROM DBA_TABLES;
DROP VIEW IF EXISTS ALL_TABLES CASCADE;
CREATE OR REPLACE VIEW ALL_TABLES AS SELECT * FROM DBA_TABLES;
DROP VIEW IF EXISTS USER_TABLES CASCADE;
CREATE OR REPLACE VIEW USER_TABLES AS SELECT * FROM DBA_TABLES WHERE OWNER = UPPER(CURRENT_SCHEMA());
CREATE OR REPLACE view TABS AS SELECT * FROM USER_TABLES;


DROP VIEW IF EXISTS DBA_PART_TABLES CASCADE;
CREATE OR REPLACE VIEW DBA_PART_TABLES
AS
SELECT UPPER(n.nspname::text) as OWNER
     , UPPER(c.relname::text) as TABLE_NAME
     , case t.partstrat when 'h' then 'HASH' when 'l' then 'LIST' when 'r' then 'RANGE' else UPPER(partstrat::text) end as PARTITIONING_TYPE
     -- SUBPARTITIONING_TYPE             VARCHAR2(9)
     , p.part_count as PARTITION_COUNT
     -- DEF_SUBPARTITION_COUNT           NUMBER
     , t.partnatts as PARTITIONING_KEY_COUNT
     -- SUBPARTITIONING_KEY_COUNT        NUMBER
     -- STATUS                           VARCHAR2(8)
     , coalesce(UPPER(s.spcname::text), 'DEFAULT') as DEF_TABLESPACE_NAME
     -- DEF_PCT_FREE                     NUMBER
     -- DEF_PCT_USED                     NUMBER
     -- DEF_INI_TRANS                    NUMBER
     -- DEF_MAX_TRANS                    NUMBER
     -- DEF_INITIAL_EXTENT               VARCHAR2(40)
     -- DEF_NEXT_EXTENT                  VARCHAR2(40)
     -- DEF_MIN_EXTENTS                  VARCHAR2(40)
     -- DEF_MAX_EXTENTS                  VARCHAR2(40)
     -- DEF_MAX_SIZE                     VARCHAR2(40)
     -- DEF_PCT_INCREASE                 VARCHAR2(40)
     -- DEF_FREELISTS                    NUMBER
     -- DEF_FREELIST_GROUPS              NUMBER
     , case c.relpersistence when 'p' then 'YES' else 'NO' end as DEF_LOGGING
     -- DEF_COMPRESSION                  VARCHAR2(8)
     -- DEF_COMPRESS_FOR                 VARCHAR2(30)
     -- DEF_BUFFER_POOL                  VARCHAR2(7)
     -- DEF_FLASH_CACHE                  VARCHAR2(7)
     -- DEF_CELL_FLASH_CACHE             VARCHAR2(7)
     -- REF_PTN_CONSTRAINT_NAME          VARCHAR2(128)
     -- INTERVAL                         VARCHAR2(1000)
     -- AUTOLIST                         VARCHAR2(3)
     -- INTERVAL_SUBPARTITION            VARCHAR2(1000)
     -- AUTOLIST_SUBPARTITION            VARCHAR2(3)
     -- IS_NESTED                        VARCHAR2(3)
     -- DEF_SEGMENT_CREATION             VARCHAR2(4)
     -- DEF_INDEXING                     VARCHAR2(3)
     -- DEF_INMEMORY                     VARCHAR2(8)
     -- DEF_INMEMORY_PRIORITY            VARCHAR2(8)
     -- DEF_INMEMORY_DISTRIBUTE          VARCHAR2(15)
     -- DEF_INMEMORY_COMPRESSION         VARCHAR2(17)
     -- DEF_INMEMORY_DUPLICATE           VARCHAR2(13)
     -- DEF_READ_ONLY                    VARCHAR2(3)
     -- DEF_CELLMEMORY                   VARCHAR2(24)
     -- DEF_INMEMORY_SERVICE             VARCHAR2(12)
     -- DEF_INMEMORY_SERVICE_NAME        VARCHAR2(1000)
  FROM pg_catalog.pg_class c
  join pg_catalog.pg_namespace n on c.relnamespace = n.oid
  join (select inhparent, count(*) part_count FROM pg_catalog.pg_inherits group by inhparent) p on p.inhparent = c.oid
  join pg_catalog.pg_partitioned_table t on t.partrelid = c.oid
  left join pg_catalog.pg_tablespace s on c.reltablespace = s.oid
 WHERE c.relkind = 'p';

DROP VIEW IF EXISTS ALL_PART_TABLES CASCADE;
CREATE OR REPLACE VIEW ALL_PART_TABLES AS SELECT * FROM DBA_PART_TABLES;
DROP VIEW IF EXISTS USER_PART_TABLES CASCADE;
CREATE OR REPLACE VIEW USER_PART_TABLES AS SELECT * FROM DBA_PART_TABLES WHERE OWNER = UPPER(CURRENT_SCHEMA());


DROP VIEW IF EXISTS DBA_TAB_PARTITIONS CASCADE;
CREATE OR REPLACE VIEW DBA_TAB_PARTITIONS
AS
SELECT UPPER(n.nspname::text) as TABLE_OWNER
     , UPPER(cp.relname::text) as TABLE_NAME
     -- COMPOSITE                  VARCHAR2(3)
     , UPPER(cc.relname::text) as PARTITION_NAME
     -- SUBPARTITION_COUNT         NUMBER
     , pg_get_partition_constraintdef(cc.oid) as HIGH_VALUE
     , length(pg_get_partition_constraintdef(cc.oid)) as HIGH_VALUE_LENGTH
     , row_number() over (partition by cp.oid order by pg_get_partition_constraintdef(cc.oid)) as PARTITION_POSITION
     , coalesce(UPPER(t.spcname::text), 'DEFAULT') as TABLESPACE_NAME
     -- PCT_FREE                   NUMBER
     -- PCT_USED                   NUMBER
     -- INI_TRANS                  NUMBER
     -- MAX_TRANS                  NUMBER
     -- INITIAL_EXTENT             NUMBER
     -- NEXT_EXTENT                NUMBER
     -- MIN_EXTENT                 NUMBER
     -- MAX_EXTENT                 NUMBER
     -- MAX_SIZE                   NUMBER
     -- PCT_INCREASE               NUMBER
     -- FREELISTS                  NUMBER
     -- FREELIST_GROUPS            NUMBER
     , case cc.relpersistence when 'p' then 'YES' else 'NO' end as LOGGING
     -- COMPRESSION                VARCHAR2(8)
     -- COMPRESS_FOR               VARCHAR2(30)
     , cc.reltuples as NUM_ROWS
     , cc.relpages as BLOCKS
     -- EMPTY_BLOCKS               NUMBER
     -- AVG_SPACE                  NUMBER
     -- CHAIN_CNT                  NUMBER
     , s.stawidth as AVG_ROW_LEN
     -- SAMPLE_SIZE                NUMBER
     , coalesce(pg_stat_get_last_analyze_time(cc.oid), pg_stat_get_last_autoanalyze_time(cc.oid)) as LAST_ANALYZED
     -- BUFFER_POOL                VARCHAR2(7)
     -- FLASH_CACHE                VARCHAR2(7)
     -- CELL_FLASH_CACHE           VARCHAR2(7)
     -- GLOBAL_STATS               VARCHAR2(3)
     -- USER_STATS                 VARCHAR2(3)
     -- IS_NESTED                  VARCHAR2(3)
     -- PARENT_TABLE_PARTITION     VARCHAR2(128)
     -- INTERVAL                   VARCHAR2(3)
     -- SEGMENT_CREATED            VARCHAR2(4)
     -- INDEXING                   VARCHAR2(4)
     -- READ_ONLY                  VARCHAR2(4)
     -- INMEMORY                   VARCHAR2(8)
     -- INMEMORY_PRIORITY          VARCHAR2(8)
     -- INMEMORY_DISTRIBUTE        VARCHAR2(15)
     -- INMEMORY_COMPRESSION       VARCHAR2(17)
     -- INMEMORY_DUPLICATE         VARCHAR2(13)
     -- CELLMEMORY                 VARCHAR2(24)
     -- INMEMORY_SERVICE           VARCHAR2(12)
     -- INMEMORY_SERVICE_NAME      VARCHAR2(1000)
     -- MEMOPTIMIZE_READ           VARCHAR2(8)
     -- MEMOPTIMIZE_WRITE          VARCHAR2(8)
  FROM pg_catalog.pg_inherits p
  join pg_catalog.pg_class cp on p.inhparent = cp.oid
  join pg_catalog.pg_class cc on p.inhrelid = cc.oid
  join pg_catalog.pg_namespace n on cc.relnamespace = n.oid
  left join pg_catalog.pg_tablespace t on cc.reltablespace = t.oid
  left join (select starelid, sum(stawidth) as stawidth FROM pg_catalog.pg_statistic group by starelid) s on cc.oid = s.starelid
 WHERE cc.relkind = 'r' and cc.relispartition;

DROP VIEW IF EXISTS ALL_TAB_PARTITIONS CASCADE;
CREATE OR REPLACE VIEW ALL_TAB_PARTITIONS AS SELECT * FROM DBA_TAB_PARTITIONS;
DROP VIEW IF EXISTS USER_TAB_PARTITIONS CASCADE;
CREATE OR REPLACE VIEW USER_TAB_PARTITIONS AS SELECT * FROM DBA_TAB_PARTITIONS WHERE TABLE_OWNER = UPPER(CURRENT_SCHEMA());


DROP VIEW IF EXISTS DBA_TAB_STATISTICS CASCADE;
CREATE OR REPLACE VIEW DBA_TAB_STATISTICS
AS
SELECT OWNER
     , TABLE_NAME
     , Null as PARTITION_NAME
     , null as PARTITION_POSITION
     -- SUBPARTITION_NAME             VARCHAR2(128)
     -- SUBPARTITION_POSITION         NUMBER
     , 'TABLE' as OBJECT_TYPE
     , NUM_ROWS
     , BLOCKS
     -- EMPTY_BLOCKS                  NUMBER
     -- AVG_SPACE                     NUMBER
     -- CHAIN_CNT                     NUMBER
     , AVG_ROW_LEN
     -- AVG_SPACE_FREELIST_BLOCKS     NUMBER
     -- NUM_FREELIST_BLOCKS           NUMBER
     -- AVG_CACHED_BLOCKS             NUMBER
     -- AVG_CACHE_HIT_RATIO           NUMBER
     -- IM_IMCU_COUNT                 NUMBER
     -- IM_BLOCK_COUNT                NUMBER
     -- IM_STAT_UPDATE_TIME           TIMESTAMP(9)
     -- SCAN_RATE                     NUMBER
     -- SAMPLE_SIZE                   NUMBER
     , LAST_ANALYZED
     -- GLOBAL_STATS                  VARCHAR2(3)
     -- USER_STATS                    VARCHAR2(3)
     -- STATTYPE_LOCKED               VARCHAR2(5)
     -- STALE_STATS                   VARCHAR2(7)
     -- NOTES                         VARCHAR2(25)
     -- SCOPE                         VARCHAR2(7)
  FROM dba_tables
 WHERE partitioned = 'NO'
 union all
SELECT TABLE_OWNER as OWNER
     , TABLE_NAME
     , PARTITION_NAME
     , PARTITION_POSITION
     -- SUBPARTITION_NAME             VARCHAR2(128)
     -- SUBPARTITION_POSITION         NUMBER
     , 'PARTITION' as OBJECT_TYPE
     , NUM_ROWS
     , BLOCKS
     -- EMPTY_BLOCKS                  NUMBER
     -- AVG_SPACE                     NUMBER
     -- CHAIN_CNT                     NUMBER
     , AVG_ROW_LEN
     -- AVG_SPACE_FREELIST_BLOCKS     NUMBER
     -- NUM_FREELIST_BLOCKS           NUMBER
     -- AVG_CACHED_BLOCKS             NUMBER
     -- AVG_CACHE_HIT_RATIO           NUMBER
     -- IM_IMCU_COUNT                 NUMBER
     -- IM_BLOCK_COUNT                NUMBER
     -- IM_STAT_UPDATE_TIME           TIMESTAMP(9)
     -- SCAN_RATE                     NUMBER
     -- SAMPLE_SIZE                   NUMBER
     , LAST_ANALYZED
     -- GLOBAL_STATS                  VARCHAR2(3)
     -- USER_STATS                    VARCHAR2(3)
     -- STATTYPE_LOCKED               VARCHAR2(5)
     -- STALE_STATS                   VARCHAR2(7)
     -- NOTES                         VARCHAR2(25)
     -- SCOPE                         VARCHAR2(7)
  FROM DBA_TAB_PARTITIONS;

DROP VIEW IF EXISTS ALL_TAB_STATISTICS CASCADE;
CREATE OR REPLACE VIEW ALL_TAB_STATISTICS AS SELECT * FROM DBA_TAB_STATISTICS;
DROP VIEW IF EXISTS USER_TAB_STATISTICS CASCADE;
CREATE OR REPLACE VIEW USER_TAB_STATISTICS AS SELECT * FROM DBA_TAB_STATISTICS WHERE OWNER = UPPER(CURRENT_SCHEMA());


DROP VIEW IF EXISTS DBA_TAB_COMMENTS CASCADE;
CREATE OR REPLACE VIEW DBA_TAB_COMMENTS
AS
SELECT UPPER(n.nspname::text) as OWNER
     , UPPER(c.relname::text) as TABLE_NAME
     , CASE c.relkind
            WHEN 'r'::"char" THEN 'TABLE'::text
            WHEN 'v'::"char" THEN 'VIEW'::text
            WHEN 'm'::"char" THEN 'MATERIALIZED VIEW'::text
            WHEN 'i'::"char" THEN 'INDEX'::text
            WHEN 'I'::"char" THEN 'PARTITIONED INDEX'::text
            WHEN 'S'::"char" THEN 'SEQUENCE'::text
            WHEN 's'::"char" THEN 'SPECIAL'::text
            WHEN 'f'::"char" THEN 'FOREIGN TABLE'::text
            WHEN 'p'::"char" THEN 'PARTITIONED TABLE'::text
            WHEN 'c'::"char" THEN 'TYPE'::text
            WHEN 't'::"char" THEN 'TOAST'::text
            ELSE c.relkind::text
        END AS TABLE_TYPE
     , d.description as COMMENTS
     -- ORIGIN_CON_ID         NUMBER
  FROM pg_catalog.pg_class c
  JOIN pg_catalog.pg_namespace n on c.relnamespace  = n.oid
  LEFT JOIN pg_catalog.pg_description d on c.oid = d.objoid and d.objsubid = 0 and d.classoid = 'pg_class'::regclass::oid;

DROP VIEW IF EXISTS ALL_TAB_COMMENTS CASCADE;
CREATE OR REPLACE VIEW ALL_TAB_COMMENTS AS SELECT * FROM DBA_TAB_COMMENTS;
DROP VIEW IF EXISTS USER_TAB_COMMENTS CASCADE;
CREATE OR REPLACE VIEW USER_TAB_COMMENTS AS SELECT * FROM DBA_TAB_COMMENTS WHERE OWNER = UPPER(CURRENT_SCHEMA());


DROP VIEW IF EXISTS DBA_TAB_MODIFICATIONS CASCADE;
CREATE OR REPLACE VIEW DBA_TAB_MODIFICATIONS
AS
SELECT UPPER(n.nspname::text) as TABLE_OWNER
     , UPPER(p.relname::text) as TABLE_NAME
     , UPPER(c.relname::text) as PARTITION_NAME
     -- SUBPARTITION_NAME            VARCHAR2(128)
     , s.n_tup_ins as INSERTS
     , s.n_tup_upd as UPDATES
     , s.n_tup_del as DELETES
     , coalesce(s.last_analyze, s.last_autovacuum) as TIMESTAMP
     -- TRUNCATED                    VARCHAR2(3)
     -- DROP_SEGMENTS                NUMBER
  FROM pg_catalog.pg_class p
  join pg_catalog.pg_namespace n on p.relnamespace = n.oid
  left join pg_catalog.pg_inherits i on i.inhparent = p.oid
  left join pg_catalog.pg_class c on i.inhrelid = c.oid
  join pg_catalog.pg_stat_all_tables s on coalesce(c.oid, p.oid) = s.relid
 WHERE p.relkind in ('r', 'p')
   and not p.relispartition;

DROP VIEW IF EXISTS ALL_TAB_MODIFICATIONS CASCADE;
CREATE OR REPLACE VIEW ALL_TAB_MODIFICATIONS AS SELECT * FROM DBA_TAB_MODIFICATIONS;
DROP VIEW IF EXISTS USER_TAB_MODIFICATIONS CASCADE;
CREATE OR REPLACE VIEW USER_TAB_MODIFICATIONS AS SELECT * FROM DBA_TAB_MODIFICATIONS WHERE TABLE_OWNER = UPPER(CURRENT_SCHEMA());


DROP VIEW IF EXISTS DBA_INDEXES CASCADE;
CREATE OR REPLACE VIEW DBA_INDEXES
AS
SELECT UPPER(nc.nspname::text) as OWNER
     , UPPER(c.relname::text) as INDEX_NAME
     -- INDEX_TYPE                         VARCHAR2(27)
     , UPPER(nt.nspname::text) as TABLE_OWNER
     , UPPER(t.relname::text) as TABLE_NAME
     , CASE c.relkind
            WHEN 'r'::"char" THEN 'TABLE'::text
            WHEN 'v'::"char" THEN 'VIEW'::text
            WHEN 'm'::"char" THEN 'MATERIALIZED VIEW'::text
            WHEN 'i'::"char" THEN 'INDEX'::text
            WHEN 'I'::"char" THEN 'PARTITIONED INDEX'::text
            WHEN 'S'::"char" THEN 'SEQUENCE'::text
            WHEN 's'::"char" THEN 'SPECIAL'::text
            WHEN 'f'::"char" THEN 'FOREIGN TABLE'::text
            WHEN 'p'::"char" THEN 'PARTITIONED TABLE'::text
            WHEN 'c'::"char" THEN 'TYPE'::text
            WHEN 't'::"char" THEN 'TOAST'::text
            ELSE c.relkind::text
        END AS TABLE_TYPE
     , case when i.indisunique then 'UNIQUE' else 'NONUNIQUE' end as UNIQUENESS
     -- COMPRESSION                        VARCHAR2(13)
     -- PREFIX_LENGTH                      NUMBER
     , coalesce(UPPER(s.spcname), 'DEFAULT') as TABLESPACE_NAME
     -- INI_TRANS                          NUMBER
     -- MAX_TRANS                          NUMBER
     -- INITIAL_EXTENT                     NUMBER
     -- NEXT_EXTENT                        NUMBER
     -- MIN_EXTENTS                        NUMBER
     -- MAX_EXTENTS                        NUMBER
     -- PCT_INCREASE                       NUMBER
     -- PCT_THRESHOLD                      NUMBER
     -- INCLUDE_COLUMN                     NUMBER
     -- FREELISTS                          NUMBER
     -- FREELIST_GROUPS                    NUMBER
     -- PCT_FREE                           NUMBER
     , case c.relpersistence when 'p' then 'YES' else 'NO' end as LOGGING
     -- BLEVEL                             NUMBER
     -- LEAF_BLOCKS                        NUMBER
     , CASE WHEN st.stadistinct >= 0 THEN st.stadistinct ELSE ROUND(ABS(st.stadistinct * c.RELTUPLES)) END as DISTINCT_KEYS
     -- AVG_LEAF_BLOCKS_PER_KEY            NUMBER
     -- AVG_DATA_BLOCKS_PER_KEY            NUMBER
     -- CLUSTERING_FACTOR                  NUMBER
     , case when i.indisvalid then 'VALID' else 'UNUSABLE' end as STATUS
     , c.reltuples as NUM_ROWS
     -- SAMPLE_SIZE                        NUMBER
     , coalesce(pg_stat_get_last_analyze_time(t.oid), pg_stat_get_last_autoanalyze_time(t.oid)) as LAST_ANALYZED
     -- DEGREE                             VARCHAR2(40)
     -- INSTANCES                          VARCHAR2(40)
     , case when c.relkind = 'I' then 'YES' else 'NO' end as PARTITIONED
     , case c.relpersistence when 't' then 'YES' else 'NO' end as TEMPORARY
     -- GENERATED                          VARCHAR2(1)
     -- SECONDARY                          VARCHAR2(1)
     -- BUFFER_POOL                        VARCHAR2(7)
     -- FLASH_CACHE                        VARCHAR2(7)
     -- CELL_FLASH_CACHE                   VARCHAR2(7)
     -- USER_STATS                         VARCHAR2(3)
     -- DURATION                           VARCHAR2(15)
     -- PCT_DIRECT_ACCESS                  NUMBER
     -- ITYP_OWNER                         VARCHAR2(128)
     -- ITYP_NAME                          VARCHAR2(128)
     -- PARAMETERS                         VARCHAR2(1000)
     -- GLOBAL_STATS                       VARCHAR2(3)
     -- DOMIDX_STATUS                      VARCHAR2(12)
     -- DOMIDX_OPSTATUS                    VARCHAR2(6)
     -- FUNCIDX_STATUS                     VARCHAR2(8)
     -- JOIN_INDEX                         VARCHAR2(3)
     -- IOT_REDUNDANT_PKEY_ELIM            VARCHAR2(3)
     -- DROPPED                            VARCHAR2(3)
     -- VISIBILITY                         VARCHAR2(9)
     -- DOMIDX_MANAGEMENT                  VARCHAR2(14)
     -- SEGMENT_CREATED                    VARCHAR2(3)
     -- ORPHANED_ENTRIES                   VARCHAR2(3)
     -- INDEXING                           VARCHAR2(7)
     -- AUTO                               VARCHAR2(3)
     -- CONSTRAINT_INDEX                   VARCHAR2(3)
  FROM pg_catalog.pg_index i
  join pg_catalog.pg_class c on i.indexrelid = c.oid
  join pg_catalog.pg_class t on i.indrelid = t.oid
  join pg_catalog.pg_namespace nc on nc.oid = c.relnamespace
  join pg_catalog.pg_namespace nt on nt.oid = t.relnamespace
  left join pg_catalog.pg_tablespace s on c.reltablespace = s.oid
  left join pg_catalog.pg_statistic st on i.indnatts = 1 and i.indkey[0] = st.staattnum and st.starelid = t.oid
 WHERE nc.nspname::text not like 'pg_toast%';

DROP VIEW IF EXISTS ALL_INDEXES CASCADE;
CREATE OR REPLACE VIEW ALL_INDEXES AS SELECT * FROM DBA_INDEXES;
DROP VIEW IF EXISTS USER_INDEXES CASCADE;
CREATE OR REPLACE VIEW USER_INDEXES AS SELECT * FROM DBA_INDEXES WHERE OWNER = UPPER(CURRENT_SCHEMA());
create or replace view IND as select * FROM DBA_INDEXES WHERE owner = UPPER(CURRENT_SCHEMA());


DROP VIEW IF EXISTS DBA_INDEX_USAGE CASCADE;
CREATE OR REPLACE VIEW DBA_INDEX_USAGE
AS
SELECT i.oid as object_id
     , UPPER(i.relname::text) as NAME
     , UPPER(n.nspname::text) as OWNER
     , pg_stat_get_numscans(i.oid) as TOTAL_ACCESS_COUNT
     -- TOTAL_EXEC_COUNT                             NUMBER
     , pg_stat_get_tuples_returned(i.oid) as TOTAL_ROWS_RETURNED
     -- BUCKET_0_ACCESS_COUNT                        NUMBER
     -- BUCKET_1_ACCESS_COUNT                        NUMBER
     -- BUCKET_2_10_ACCESS_COUNT                     NUMBER
     -- BUCKET_2_10_ROWS_RETURNED                    NUMBER
     -- BUCKET_11_100_ACCESS_COUNT                   NUMBER
     -- BUCKET_11_100_ROWS_RETURNED                  NUMBER
     -- BUCKET_101_1000_ACCESS_COUNT                 NUMBER
     -- BUCKET_101_1000_ROWS_RETURNED                NUMBER
     -- BUCKET_1000_PLUS_ACCESS_COUNT                NUMBER
     -- BUCKET_1000_PLUS_ROWS_RETURNED               NUMBER
     -- LAST_USED                                    DATE
  FROM pg_catalog.pg_class i
  join pg_catalog.pg_namespace n on n.oid = i.relnamespace
 WHERE i.relkind in ('i', 'I') and n.nspname::text not like 'pg_toast%';

DROP VIEW IF EXISTS ALL_INDEX_USAGE CASCADE;
CREATE OR REPLACE VIEW ALL_INDEX_USAGE AS SELECT * FROM DBA_INDEX_USAGE;
DROP VIEW IF EXISTS USER_INDEX_USAGE CASCADE;
CREATE OR REPLACE VIEW USER_INDEX_USAGE AS SELECT * FROM DBA_INDEX_USAGE WHERE OWNER = UPPER(CURRENT_SCHEMA());


DROP VIEW IF EXISTS DBA_IND_COLUMNS CASCADE;
CREATE OR REPLACE VIEW DBA_IND_COLUMNS
AS
SELECT UPPER(nc.nspname::text) as INDEX_OWNER
     , UPPER(c.relname::text) as INDEX_NAME
     , UPPER(nt.nspname::text) as TABLE_OWNER
     , UPPER(t.relname::text) as TABLE_NAME
     , UPPER(a.attname::text) as COLUMN_NAME
     , i.row_id as COLUMN_POSITION
     , a.attlen as COLUMN_LENGTH
     -- CHAR_LENGTH                        NUMBER
     , case indoption when 0 then 'ASC' when 3 then 'DESC' end as DESCEND
     -- COLLATED_COLUMN_ID                 NUMBER
  FROM (select *, row_number() over (partition by indexrelid) as row_id
          FROM (select indexrelid, indrelid, unnest(indkey) as indkey, unnest(indoption) as indoption
                  FROM pg_catalog.pg_index
                 WHERE indkey::text != '0') as foo) i
  join pg_catalog.pg_class c on i.indexrelid = c.oid
  join pg_catalog.pg_class t on i.indrelid = t.oid
  join pg_catalog.pg_namespace nc on nc.oid = c.relnamespace
  join pg_catalog.pg_namespace nt on nt.oid = t.relnamespace
  join pg_catalog.pg_attribute a on a.attrelid = i.indrelid and i.indkey = a.attnum
 WHERE nc.nspname::text not like 'pg_toast%';

DROP VIEW IF EXISTS ALL_IND_COLUMNS CASCADE;
CREATE OR REPLACE VIEW ALL_IND_COLUMNS AS SELECT * FROM DBA_IND_COLUMNS;
DROP VIEW IF EXISTS USER_IND_COLUMNS CASCADE;
CREATE OR REPLACE VIEW USER_IND_COLUMNS AS SELECT * FROM DBA_IND_COLUMNS WHERE INDEX_OWNER = UPPER(CURRENT_SCHEMA());


DROP VIEW IF EXISTS DBA_IND_PARTITIONS CASCADE;
CREATE OR REPLACE VIEW DBA_IND_PARTITIONS
AS
SELECT UPPER(n.nspname::text) as INDEX_OWNER
     , UPPER(cp.relname::text) as INDEX_NAME
     -- COMPOSITE                    VARCHAR2(3)
     , UPPER(cc.relname::text) as PARTITION_NAME
     , UPPER(nt.nspname::text) as TABLE_OWNER
     , UPPER(ct.relname::text) as TABLE_NAME
     -- SUBPARTITION_COUNT           NUMBER
     , pg_get_partition_constraintdef(ct.oid) as HIGH_VALUE
     , length(pg_get_partition_constraintdef(ct.oid)) as HIGH_VALUE_LENGTH
     , row_number() over (partition by cp.oid order by pg_get_partition_constraintdef(cc.oid)) as PARTITION_POSITION
     -- STATUS                       VARCHAR2(8)
     , coalesce(UPPER(t.spcname::text), 'DEFAULT') as TABLESPACE_NAME
     -- PCT_FREE                     NUMBER
     -- INI_TRANS                    NUMBER
     -- MAX_TRANS                    NUMBER
     -- INITIAL_EXTENT               NUMBER
     -- NEXT_EXTENT                  NUMBER
     -- MIN_EXTENT                   NUMBER
     -- MAX_EXTENT                   NUMBER
     -- MAX_SIZE                     NUMBER
     -- PCT_INCREASE                 NUMBER
     -- FREELISTS                    NUMBER
     -- FREELIST_GROUPS              NUMBER
     , case cc.relpersistence when 'p' then 'YES' else 'NO' end as LOGGING
     -- COMPRESSION                  VARCHAR2(13)
     -- BLEVEL                       NUMBER
     -- LEAF_BLOCKS                  NUMBER
     -- DISTINCT_KEYS                NUMBER
     -- AVG_LEAF_BLOCKS_PER_KEY      NUMBER
     -- AVG_DATA_BLOCKS_PER_KEY      NUMBER
     -- CLUSTERING_FACTOR            NUMBER
     , cc.reltuples as NUM_ROWS
     -- SAMPLE_SIZE                  NUMBER
     , coalesce(pg_stat_get_last_analyze_time(cc.oid), pg_stat_get_last_autoanalyze_time(cc.oid)) as LAST_ANALYZED
     -- BUFFER_POOL                  VARCHAR2(7)
     -- FLASH_CACHE                  VARCHAR2(7)
     -- CELL_FLASH_CACHE             VARCHAR2(7)
     -- USER_STATS                   VARCHAR2(3)
     -- PCT_DIRECT_ACCESS            NUMBER
     -- GLOBAL_STATS                 VARCHAR2(3)
     -- DOMIDX_OPSTATUS              VARCHAR2(6)
     -- PARAMETERS                   VARCHAR2(1000)
     -- INTERVAL                     VARCHAR2(3)
     -- SEGMENT_CREATED              VARCHAR2(3)
     -- ORPHANED_ENTRIES             VARCHAR2(3)
  FROM pg_catalog.pg_inherits p
  join pg_catalog.pg_class cp on p.inhparent = cp.oid
  join pg_catalog.pg_class cc on p.inhrelid = cc.oid
  join pg_catalog.pg_namespace n on cc.relnamespace = n.oid
  join pg_catalog.pg_index i on i.indexrelid = cc.oid
  join pg_catalog.pg_class ct on i.indrelid = ct.oid
  join pg_catalog.pg_namespace nt on ct.relnamespace = nt.oid
  left join pg_catalog.pg_tablespace t on cc.reltablespace = t.oid
 WHERE cc.relkind = 'i' and cc.relispartition;

DROP VIEW IF EXISTS ALL_IND_PARTITIONS CASCADE;
CREATE OR REPLACE VIEW ALL_IND_PARTITIONS AS SELECT * FROM DBA_IND_PARTITIONS;
DROP VIEW IF EXISTS USER_IND_PARTITIONS CASCADE;
CREATE OR REPLACE VIEW USER_IND_PARTITIONS AS SELECT * FROM DBA_IND_PARTITIONS WHERE INDEX_OWNER = UPPER(CURRENT_SCHEMA());


DROP VIEW IF EXISTS DBA_IND_STATISTICS CASCADE;
CREATE OR REPLACE VIEW DBA_IND_STATISTICS
AS
SELECT OWNER
     , INDEX_NAME
     , TABLE_OWNER
     , TABLE_NAME
     , null as PARTITION_NAME
     , null as PARTITION_POSITION
     -- SUBPARTITION_NAME             VARCHAR2(128)
     -- SUBPARTITION_POSITION         NUMBER
     , 'INDEX' as OBJECT_TYPE
     -- BLEVEL                        NUMBER
     -- LEAF_BLOCKS                   NUMBER
     , DISTINCT_KEYS
     -- AVG_LEAF_BLOCKS_PER_KEY       NUMBER
     -- AVG_DATA_BLOCKS_PER_KEY       NUMBER
     -- CLUSTERING_FACTOR             NUMBER
     , NUM_ROWS
     -- AVG_CACHED_BLOCKS             NUMBER
     -- AVG_CACHE_HIT_RATIO           NUMBER
     -- SAMPLE_SIZE                   NUMBER
     , LAST_ANALYZED
     -- GLOBAL_STATS                  VARCHAR2(3)
     -- USER_STATS                    VARCHAR2(3)
     -- STATTYPE_LOCKED               VARCHAR2(5)
     -- STALE_STATS                   VARCHAR2(3)
     -- SCOPE                         VARCHAR2(7)
  FROM DBA_INDEXES
 WHERE partitioned = 'NO'
 union all
select INDEX_OWNER as OWNER
     , INDEX_NAME
     , TABLE_OWNER
     , TABLE_NAME
     , PARTITION_NAME
     , PARTITION_POSITION
     -- SUBPARTITION_NAME             VARCHAR2(128)
     -- SUBPARTITION_POSITION         NUMBER
     , 'PARTITION' as OBJECT_TYPE
     -- BLEVEL                        NUMBER
     -- LEAF_BLOCKS                   NUMBER
     , null as DISTINCT_KEYS
     -- AVG_LEAF_BLOCKS_PER_KEY       NUMBER
     -- AVG_DATA_BLOCKS_PER_KEY       NUMBER
     -- CLUSTERING_FACTOR             NUMBER
     , NUM_ROWS
     -- AVG_CACHED_BLOCKS             NUMBER
     -- AVG_CACHE_HIT_RATIO           NUMBER
     -- SAMPLE_SIZE                   NUMBER
     , LAST_ANALYZED
     -- GLOBAL_STATS                  VARCHAR2(3)
     -- USER_STATS                    VARCHAR2(3)
     -- STATTYPE_LOCKED               VARCHAR2(5)
     -- STALE_STATS                   VARCHAR2(3)
     -- SCOPE                         VARCHAR2(7)
  FROM DBA_IND_PARTITIONS;

DROP VIEW IF EXISTS ALL_IND_STATISTICS CASCADE;
CREATE OR REPLACE VIEW ALL_IND_STATISTICS AS SELECT * FROM DBA_IND_STATISTICS;
DROP VIEW IF EXISTS USER_IND_STATISTICS CASCADE;
CREATE OR REPLACE VIEW USER_IND_STATISTICS AS SELECT * FROM DBA_IND_STATISTICS WHERE OWNER = UPPER(CURRENT_SCHEMA());


DROP VIEW IF EXISTS DBA_PART_INDEXES CASCADE;
CREATE OR REPLACE VIEW DBA_PART_INDEXES
AS
SELECT UPPER(n.nspname::text) as OWNER
     , UPPER(i.relname::text) as INDEX_NAME
     , UPPER(tt.relname::text) as TABLE_NAME
     , case t.partstrat when 'h' then 'HASH' when 'l' then 'LIST' when 'r' then 'RANGE' else UPPER(partstrat::text) end as PARTITIONING_TYPE
     -- SUBPARTITIONING_TYPE                    VARCHAR2(9)
     , p.part_count as PARTITION_COUNT
     -- DEF_SUBPARTITION_COUNT                  NUMBER
     , t.partnatts as PARTITIONING_KEY_COUNT
     -- SUBPARTITIONING_KEY_COUNT               NUMBER
     -- LOCALITY                                VARCHAR2(6)
     -- ALIGNMENT                               VARCHAR2(12)
     , coalesce(UPPER(s.spcname::text), 'DEFAULT') as DEF_TABLESPACE_NAME
     -- DEF_PCT_FREE                   NOT NULL NUMBER
     -- DEF_INI_TRANS                  NOT NULL NUMBER
     -- DEF_MAX_TRANS                  NOT NULL NUMBER
     -- DEF_INITIAL_EXTENT                      VARCHAR2(40)
     -- DEF_NEXT_EXTENT                         VARCHAR2(40)
     -- DEF_MIN_EXTENTS                         VARCHAR2(40)
     -- DEF_MAX_EXTENTS                         VARCHAR2(40)
     -- DEF_MAX_SIZE                            VARCHAR2(40)
     -- DEF_PCT_INCREASE                        VARCHAR2(40)
     -- DEF_FREELISTS                  NOT NULL NUMBER
     -- DEF_FREELIST_GROUPS            NOT NULL NUMBER
     , case i.relpersistence when 'p' then 'YES' else 'NO' end as DEF_LOGGING
     -- DEF_BUFFER_POOL                         VARCHAR2(7)
     -- DEF_FLASH_CACHE                         VARCHAR2(7)
     -- DEF_CELL_FLASH_CACHE                    VARCHAR2(7)
     -- DEF_PARAMETERS                          VARCHAR2(1000)
     -- INTERVAL                                VARCHAR2(1000)
     -- AUTOLIST                                VARCHAR2(3)
     -- INTERVAL_SUBPARTITION                   VARCHAR2(1000)
     -- AUTOLIST_SUBPARTITION                   VARCHAR2(3)
  FROM pg_catalog.pg_class i
  join pg_catalog.pg_namespace n on i.relnamespace = n.oid
  join pg_catalog.pg_index it on i.oid = it.indexrelid
  join pg_catalog.pg_class tt on tt.oid = it.indrelid
  join (select inhparent, count(*) part_count FROM pg_catalog.pg_inherits group by inhparent) p on p.inhparent = i.oid
  join pg_catalog.pg_partitioned_table t on t.partrelid = it.indrelid
  left join pg_catalog.pg_tablespace s on i.reltablespace = s.oid
 WHERE i.relkind = 'I';

DROP VIEW IF EXISTS ALL_PART_INDEXES CASCADE;
CREATE OR REPLACE VIEW ALL_PART_INDEXES AS SELECT * FROM DBA_PART_INDEXES;
DROP VIEW IF EXISTS USER_PART_INDEXES CASCADE;
CREATE OR REPLACE VIEW USER_PART_INDEXES AS SELECT * FROM DBA_PART_INDEXES WHERE OWNER = UPPER(CURRENT_SCHEMA());


DROP VIEW IF EXISTS DBA_MVIEWS CASCADE;
CREATE OR REPLACE VIEW DBA_MVIEWS
AS
SELECT UPPER(schemaname::text) as OWNER
     , UPPER(matviewname::text) as MVIEW_NAME
     -- CONTAINER_NAME               NOT NULL VARCHAR2(128)
     , definition as QUERY
     , length(definition) as QUERY_LEN
     -- UPDATABLE                             VARCHAR2(1)
     -- UPDATE_LOG                            VARCHAR2(128)
     -- MASTER_ROLLBACK_SEG                   VARCHAR2(128)
     -- MASTER_LINK                           VARCHAR2(128)
     -- REWRITE_ENABLED                       VARCHAR2(1)
     -- REWRITE_CAPABILITY                    VARCHAR2(9)
     -- REFRESH_MODE                          VARCHAR2(9)
     -- REFRESH_METHOD                        VARCHAR2(8)
     -- BUILD_MODE                            VARCHAR2(9)
     -- FAST_REFRESHABLE                      VARCHAR2(18)
     -- LAST_REFRESH_TYPE                     VARCHAR2(8)
     -- LAST_REFRESH_DATE                     DATE
     -- LAST_REFRESH_END_TIME                 DATE
     -- STALENESS                             VARCHAR2(19)
     -- AFTER_FAST_REFRESH                    VARCHAR2(19)
     -- UNKNOWN_PREBUILT                      VARCHAR2(1)
     -- UNKNOWN_PLSQL_FUNC                    VARCHAR2(1)
     -- UNKNOWN_EXTERNAL_TABLE                VARCHAR2(1)
     -- UNKNOWN_CONSIDER_FRESH                VARCHAR2(1)
     -- UNKNOWN_IMPORT                        VARCHAR2(1)
     -- UNKNOWN_TRUSTED_FD                    VARCHAR2(1)
     -- COMPILE_STATE                         VARCHAR2(19)
     -- USE_NO_INDEX                          VARCHAR2(1)
     -- STALE_SINCE                           DATE
     -- NUM_PCT_TABLES                        NUMBER
     -- NUM_FRESH_PCT_REGIONS                 NUMBER
     -- NUM_STALE_PCT_REGIONS                 NUMBER
     -- SEGMENT_CREATED                       VARCHAR2(3)
     -- EVALUATION_EDITION                    VARCHAR2(128)
     -- UNUSABLE_BEFORE                       VARCHAR2(128)
     -- UNUSABLE_BEGINNING                    VARCHAR2(128)
     -- DEFAULT_COLLATION                     VARCHAR2(100)
     -- ON_QUERY_COMPUTATION                  VARCHAR2(1)
  FROM pg_catalog.pg_matviews;

DROP VIEW IF EXISTS ALL_MVIEWS CASCADE;
CREATE OR REPLACE VIEW ALL_MVIEWS AS SELECT * FROM DBA_MVIEWS;
DROP VIEW IF EXISTS USER_MVIEWS CASCADE;
CREATE OR REPLACE VIEW USER_MVIEWS AS SELECT * FROM DBA_MVIEWS WHERE OWNER = UPPER(CURRENT_SCHEMA());


DROP VIEW IF EXISTS COLUMN_PRIVILEGES CASCADE;
CREATE OR REPLACE VIEW COLUMN_PRIVILEGES
AS
SELECT UPPER(GRANTEE::text) as GRANTEE
     , UPPER(table_schema::text) as OWNER
     , UPPER(TABLE_NAME::text) as TABLE_NAME
     , UPPER(COLUMN_NAME::text) as COLUMN_NAME
     , UPPER(GRANTOR::text) as GRANTOR
     , case when count(case when privilege_type = 'INSERT' then 1 else null end) > 0 then 'Y' else 'N' end as INSERT_PRIV
     , case when count(case when privilege_type = 'UPDATE' then 1 else null end) > 0 then 'Y' else 'N' end as UPDATE_PRIV
     , case when count(case when privilege_type = 'SELECT' then 1 else null end) > 0 then 'Y' else 'N' end as SELECT_PRIV
     , case when count(case when privilege_type = 'REFERENCES' then 1 else null end) > 0 then 'Y' else 'N' end as REFERENCES_PRIV
     -- CREATED                      VARCHAR2
  FROM information_schema.column_privileges
 WHERE GRANTEE != GRANTOR
 group by UPPER(GRANTEE::text)
     , UPPER(table_schema::text)
     , UPPER(TABLE_NAME::text)
     , UPPER(COLUMN_NAME::text)
     , UPPER(GRANTOR::text);


DROP VIEW IF EXISTS DBA_COL_PRIVS CASCADE;
CREATE OR REPLACE VIEW DBA_COL_PRIVS
AS
SELECT UPPER(GRANTEE::text) as GRANTEE
     , UPPER(table_schema::text) as OWNER
     , UPPER(TABLE_NAME::text) as TABLE_NAME
     , UPPER(COLUMN_NAME::text) as COLUMN_NAME
     , UPPER(GRANTOR::text) as GRANTOR
     , privilege_type as PRIVILEGE
     , is_grantable as GRANTABLE
     -- COMMON                       VARCHAR2(3)
     -- INHERITED                    VARCHAR2(3)
  FROM information_schema.column_privileges
 WHERE GRANTEE != GRANTOR;

DROP VIEW IF EXISTS ALL_COL_PRIVS CASCADE;
CREATE OR REPLACE VIEW ALL_COL_PRIVS AS SELECT * FROM DBA_COL_PRIVS;
DROP VIEW IF EXISTS USER_COL_PRIVS CASCADE;
CREATE OR REPLACE VIEW USER_COL_PRIVS AS SELECT * FROM DBA_COL_PRIVS WHERE GRANTEE = UPPER(CURRENT_SCHEMA()) OR GRANTOR = UPPER(CURRENT_SCHEMA()) OR OWNER = UPPER(CURRENT_SCHEMA());


DROP VIEW IF EXISTS DBA_CONNECT_ROLE_GRANTEES CASCADE;
CREATE OR REPLACE VIEW DBA_CONNECT_ROLE_GRANTEES
AS
SELECT UPPER(rolname::text) as GRANTEE
     , UPPER(rolname::text) as PATH_OF_CONNECT_ROLE_GRANT
     , 'NO' as ADMIN_OPT
  FROM pg_catalog.pg_roles
 WHERE rolcanlogin;

DROP VIEW IF EXISTS ALL_CONNECT_ROLE_GRANTEES CASCADE;
CREATE OR REPLACE VIEW ALL_CONNECT_ROLE_GRANTEES AS SELECT * FROM DBA_CONNECT_ROLE_GRANTEES;
DROP VIEW IF EXISTS USER_CONNECT_ROLE_GRANTEES CASCADE;
CREATE OR REPLACE VIEW USER_CONNECT_ROLE_GRANTEES AS SELECT * FROM DBA_CONNECT_ROLE_GRANTEES WHERE GRANTEE = UPPER(CURRENT_SCHEMA());


DROP VIEW IF EXISTS DBA_ROLES CASCADE;
CREATE OR REPLACE VIEW DBA_ROLES
AS
SELECT rolname as ROLE
     , oid as ROLE_ID
     -- PASSWORD_REQUIRED            VARCHAR2(8)
     -- AUTHENTICATION_TYPE          VARCHAR2(11)
     -- COMMON                       VARCHAR2(3)
     -- ORACLE_MAINTAINED            VARCHAR2(1)
     -- INHERITED                    VARCHAR2(3)
     -- IMPLICIT                     VARCHAR2(3)
     -- EXTERNAL_NAME                VARCHAR2(4000)
  FROM pg_catalog.pg_roles;

DROP VIEW IF EXISTS ALL_ROLES CASCADE;
CREATE OR REPLACE VIEW ALL_ROLES AS SELECT * FROM DBA_ROLES;


DROP VIEW IF EXISTS ROLE_TAB_PRIVS CASCADE;
CREATE OR REPLACE VIEW ROLE_TAB_PRIVS
AS
SELECT UPPER(grantee::text) as ROLE
     , UPPER(table_schema::text) as OWNER
     , UPPER(table_name::text) as TABLE_NAME
     , UPPER(column_name::text) as COLUMN_NAME
     , privilege_type as PRIVILEGE
     , is_grantable as GRANTABLE
     -- COMMON                       VARCHAR2(3)
     -- INHERITED                    VARCHAR2(3)
  FROM information_schema.role_column_grants
 WHERE grantee != grantor
 union all
select UPPER(grantee::text) as ROLE
     , UPPER(table_schema::text) as OWNER
     , UPPER(table_name::text) as TABLE_NAME
     , NULL as COLUMN_NAME
     , privilege_type as PRIVILEGE
     , is_grantable as GRANTABLE
     -- COMMON                       VARCHAR2(3)
     -- INHERITED                    VARCHAR2(3)
  FROM information_schema.role_table_grants
 WHERE grantee != grantor;


DROP VIEW IF EXISTS TABLE_PRIVILEGES CASCADE;
CREATE OR REPLACE VIEW TABLE_PRIVILEGES
AS
SELECT UPPER(GRANTEE::text) as GRANTEE
     , UPPER(table_schema::text) as OWNER
     , UPPER(table_name::text) as TABLE_NAME
     , UPPER(GRANTOR::text) as GRANTOR
     , case when count(case when privilege_type = 'SELECT' then 1 else null end) > 0 then 'Y' else 'N' end as SELECT_PRIV
     , case when count(case when privilege_type = 'INSERT' then 1 else null end) > 0 then 'Y' else 'N' end as INSERT_PRIV
     , case when count(case when privilege_type = 'DELETE' then 1 else null end) > 0 then 'Y' else 'N' end as DELETE_PRIV
     , case when count(case when privilege_type = 'UPDATE' then 1 else null end) > 0 then 'Y' else 'N' end as UPDATE_PRIV
     , case when count(case when privilege_type = 'REFERENCES' then 1 else null end) > 0 then 'Y' else 'N' end as REFERENCES_PRIV
     , case when count(case when privilege_type = 'TRIGGER' then 1 else null end) > 0 then 'Y' else 'N' end as TRIGGER_PRIV
     , case when count(case when privilege_type = 'TRUNCATE' then 1 else null end) > 0 then 'Y' else 'N' end as TRUNCATE_PRIV
     -- CREATED                      VARCHAR2
  FROM information_schema.table_privileges
 WHERE GRANTEE != GRANTOR
 group by UPPER(GRANTEE::text)
     , UPPER(table_schema::text)
     , UPPER(table_name::text)
     , UPPER(GRANTOR::text);


DROP VIEW IF EXISTS DBA_TAB_PRIVS CASCADE;
CREATE OR REPLACE VIEW DBA_TAB_PRIVS
AS
SELECT UPPER(GRANTEE::text) as GRANTEE
     , UPPER(table_schema::text) as OWNER
     , UPPER(table_name::text) as TABLE_NAME
     , UPPER(GRANTOR::text) as GRANTOR
     , privilege_type as PRIVILEGE
     , is_grantable as GRANTABLE
     , with_hierarchy as HIERARCHY
     -- COMMON                       VARCHAR2(3)
     -- TYPE                         VARCHAR2(24)
     -- INHERITED                    VARCHAR2(3)
  FROM information_schema.table_privileges
 WHERE GRANTEE != GRANTOR;

DROP VIEW IF EXISTS ALL_TAB_PRIVS CASCADE;
CREATE OR REPLACE VIEW ALL_TAB_PRIVS AS SELECT * FROM DBA_TAB_PRIVS;
DROP VIEW IF EXISTS USER_TAB_PRIVS CASCADE;
CREATE OR REPLACE VIEW USER_TAB_PRIVS AS SELECT * FROM DBA_TAB_PRIVS WHERE GRANTEE = UPPER(CURRENT_SCHEMA()) OR OWNER = UPPER(CURRENT_SCHEMA()) OR GRANTOR = UPPER(CURRENT_SCHEMA());


DROP VIEW IF EXISTS V$PARAMETER CASCADE;
CREATE OR REPLACE VIEW V$PARAMETER
AS
SELECT
     -- NUM                     NUMBER
       NAME
     , case vartype when 'bool' then 1 when 'string' then 2 when 'integer' then 3 when 'enum' then 4 when 'real' then 6 end as TYPE
     , vartype as TYPE_NAME
     , setting as VALUE
     , setting as DISPLAY_VALUE
     , boot_val as DEFAULT_VALUE
     , case when setting = boot_val then 'TRUE' else 'FALSE' end as ISDEFAULT
     -- ISSES_MODIFIABLE
     -- ISSYS_MODIFIABLE
     -- ISPDB_MODIFIABLE        VARCHAR2(5)
     -- ISINSTANCE_MODIFIABLE   VARCHAR2(5)
     , case when context = 'internal' then 'FLASE' else 'TRUE' end as ISMODIFIED
     , case when context = 'internal' then 'TRUE' else 'FALSE' end as ISADJUSTED
     -- ISDEPRECATED            VARCHAR2(5)
     -- ISBASIC                 VARCHAR2(5)
     , short_desc as DESCRIPTION
     -- UPDATE_COMMENT          VARCHAR2(255)
     -- HASH                    NUMBER
     -- CON_ID                  NUMBER
  FROM pg_catalog.pg_settings;


DROP VIEW IF EXISTS V$SPPARAMETER CASCADE;
CREATE OR REPLACE VIEW V$SPPARAMETER
AS
SELECT
     -- FAMILY              VARCHAR2(80)
     -- SID                 VARCHAR2(80)
       NAME
     , case vartype when 'bool' then 1 when 'string' then 2 when 'integer' then 3 when 'enum' then 4 when 'real' then 6 end as TYPE
     , vartype as TYPE_NAME
     , setting as VALUE
     , setting as DISPLAY_VALUE
     , case when sourcefile is null then 'FALSE' else 'TRUE' end as ISSPECIFIED
     -- ORDINAL             NUMBER
     -- UPDATE_COMMENT      VARCHAR2(255)
     -- CON_ID              NUMBER
  FROM pg_catalog.pg_settings;


DROP VIEW IF EXISTS V$PARAMETER_VALID_VALUES CASCADE;
CREATE OR REPLACE VIEW V$PARAMETER_VALID_VALUES
AS
SELECT
     -- NUM                   NUMBER
       NAME
     , row_number() over (partition by name) as ORDINAL
     , VALUE
     , case when boot_val = VALUE then 'TRUE' else 'FALSE' end as ISDEFAULT
     -- CON_ID                NUMBER
  FROM (select name, boot_val, unnest(enumvals) as VALUE FROM pg_catalog.pg_settings) as p;


DROP VIEW IF EXISTS DBA_USERS CASCADE;
CREATE OR REPLACE VIEW DBA_USERS
AS
SELECT UPPER(usename::text) as USERNAME
     , usesysid as USER_ID
     -- passwd as PASSWORD
     -- ACCOUNT_STATUS                NOT NULL VARCHAR2(32)
     -- LOCK_DATE                              DATE
     -- EXPIRY_DATE                            DATE
     -- DEFAULT_TABLESPACE            NOT NULL VARCHAR2(30)
     -- TEMPORARY_TABLESPACE          NOT NULL VARCHAR2(30)
     -- LOCAL_TEMP_TABLESPACE                  VARCHAR2(30)
     -- CREATED                       NOT NULL DATE
     -- PROFILE                       NOT NULL VARCHAR2(128)
     -- INITIAL_RSRC_CONSUMER_GROUP            VARCHAR2(128)
     -- EXTERNAL_NAME                          VARCHAR2(4000)
     -- PASSWORD_VERSIONS                      VARCHAR2(17)
     -- EDITIONS_ENABLED                       VARCHAR2(1)
     -- AUTHENTICATION_TYPE                    VARCHAR2(8)
     -- PROXY_ONLY_CONNECT                     VARCHAR2(1)
     -- COMMON                                 VARCHAR2(3)
     -- LAST_LOGIN                             TIMESTAMP(9) WITH TIME ZONE
     -- ORACLE_MAINTAINED                      VARCHAR2(1)
     -- INHERITED                              VARCHAR2(3)
     -- DEFAULT_COLLATION                      VARCHAR2(100)
     -- IMPLICIT                               VARCHAR2(3)
     -- ALL_SHARD                              VARCHAR2(3)
     -- PASSWORD_CHANGE_DATE                   DATE
  FROM pg_catalog.pg_user;

DROP VIEW IF EXISTS ALL_USERS CASCADE;
CREATE OR REPLACE VIEW ALL_USERS AS SELECT * FROM DBA_USERS;


DROP VIEW IF EXISTS V$SESSION CASCADE;
CREATE OR REPLACE VIEW V$SESSION
AS
SELECT
     -- SADDR                                              RAW(8)
       pid as SID
     -- SERIAL#                                            NUMBER
     -- AUDSID                                             NUMBER
     -- PADDR                                              RAW(8)
     -- USER#                                              NUMBER
     , usename as USERNAME
     -- COMMAND                                            NUMBER
     -- OWNERID                                            NUMBER
     -- TADDR                                              VARCHAR2(16)
     -- LOCKWAIT                                           VARCHAR2(16)
     , state as STATUS
     -- SERVER                                             VARCHAR2(9)
     -- SCHEMA#                                            NUMBER
     -- SCHEMANAME                                         VARCHAR2(128)
     -- OSUSER                                             VARCHAR2(128)
     -- PROCESS                                            VARCHAR2(24)
     , coalesce(client_hostname, client_addr::text) as MACHINE
     , client_port as PORT
     -- TERMINAL                                           VARCHAR2(30)
     , application_name as PROGRAM
     , backend_type as TYPE
     -- SQL_ADDRESS                                        RAW(8)
     -- SQL_HASH_VALUE                                     NUMBER
     -- SQL_ID                                             VARCHAR2(13)
     , query as SQL_TEXT
     -- SQL_CHILD_NUMBER                                   NUMBER
     -- SQL_EXEC_START                                     DATE
     -- SQL_EXEC_ID                                        NUMBER
     -- PREV_SQL_ADDR                                      RAW(8)
     -- PREV_HASH_VALUE                                    NUMBER
     -- PREV_SQL_ID                                        VARCHAR2(13)
     -- PREV_CHILD_NUMBER                                  NUMBER
     -- PREV_EXEC_START                                    DATE
     -- PREV_EXEC_ID                                       NUMBER
     -- PLSQL_ENTRY_OBJECT_ID                              NUMBER
     -- PLSQL_ENTRY_SUBPROGRAM_ID                          NUMBER
     -- PLSQL_OBJECT_ID                                    NUMBER
     -- PLSQL_SUBPROGRAM_ID                                NUMBER
     -- MODULE                                             VARCHAR2(64)
     -- MODULE_HASH                                        NUMBER
     -- ACTION                                             VARCHAR2(64)
     -- ACTION_HASH                                        NUMBER
     , client_addr as CLIENT_INFO
     -- FIXED_TABLE_SEQUENCE                               NUMBER
     -- ROW_WAIT_OBJ#                                      NUMBER
     -- ROW_WAIT_FILE#                                     NUMBER
     -- ROW_WAIT_BLOCK#                                    NUMBER
     -- ROW_WAIT_ROW#                                      NUMBER
     -- TOP_LEVEL_CALL#                                    NUMBER
     , backend_start as LOGON_TIME
     -- LAST_CALL_ET                                       NUMBER
     -- PDML_ENABLED                                       VARCHAR2(3)
     -- FAILOVER_TYPE                                      VARCHAR2(13)
     -- FAILOVER_METHOD                                    VARCHAR2(10)
     -- FAILED_OVER                                        VARCHAR2(3)
     -- RESOURCE_CONSUMER_GROUP                            VARCHAR2(32)
     -- PDML_STATUS                                        VARCHAR2(8)
     -- PDDL_STATUS                                        VARCHAR2(8)
     -- PQ_STATUS                                          VARCHAR2(8)
     -- CURRENT_QUEUE_DURATION                             NUMBER
     -- CLIENT_IDENTIFIER                                  VARCHAR2(64)
     -- BLOCKING_SESSION_STATUS                            VARCHAR2(11)
     -- BLOCKING_INSTANCE                                  NUMBER
     -- BLOCKING_SESSION                                   NUMBER
     -- FINAL_BLOCKING_SESSION_STATUS                      VARCHAR2(11)
     -- FINAL_BLOCKING_INSTANCE                            NUMBER
     -- FINAL_BLOCKING_SESSION                             NUMBER
     -- SEQ#                                               NUMBER
     -- EVENT#                                             NUMBER
     , wait_event as EVENT
     -- P1TEXT                                             VARCHAR2(64)
     -- P1                                                 NUMBER
     -- P1RAW                                              RAW(8)
     -- P2TEXT                                             VARCHAR2(64)
     -- P2                                                 NUMBER
     -- P2RAW                                              RAW(8)
     -- P3TEXT                                             VARCHAR2(64)
     -- P3                                                 NUMBER
     -- P3RAW                                              RAW(8)
     -- WAIT_CLASS_ID                                      NUMBER
     -- WAIT_CLASS#                                        NUMBER
     , wait_event_type as WAIT_CLASS
     -- WAIT_TIME                                          NUMBER
     -- SECONDS_IN_WAIT                                    NUMBER
     -- STATE
     -- WAIT_TIME_MICRO                                    NUMBER
     -- TIME_REMAINING_MICRO                               NUMBER
     -- TIME_SINCE_LAST_WAIT_MICRO                         NUMBER
     -- SERVICE_NAME                                       VARCHAR2(64)
     -- SQL_TRACE                                          VARCHAR2(8)
     -- SQL_TRACE_WAITS                                    VARCHAR2(5)
     -- SQL_TRACE_BINDS                                    VARCHAR2(5)
     -- SQL_TRACE_PLAN_STATS                               VARCHAR2(10)
     -- SESSION_EDITION_ID                                 NUMBER
     -- CREATOR_ADDR                                       RAW(8)
     -- CREATOR_SERIAL#                                    NUMBER
     -- ECID                                               VARCHAR2(64)
     -- SQL_TRANSLATION_PROFILE_ID                         NUMBER
     -- PGA_TUNABLE_MEM                                    NUMBER
     -- SHARD_DDL_STATUS                                   VARCHAR2(8)
     -- CON_ID                                             NUMBER
     -- EXTERNAL_NAME                                      VARCHAR2(1024)
     -- PLSQL_DEBUGGER_CONNECTED                           VARCHAR2(5)
FROM pg_catalog.pg_stat_activity;


-- Exit current session
\q
