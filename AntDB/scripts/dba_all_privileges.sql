-- This scripts contains following object's definition:
-- =============================================================================
--     1.     View: DBA_DETAIL_PRIVILEGES
--     2.     View: DBA_ALL_PRIVILEGES
--     3. Function: PG_DROP_USER_CASCADE


-- 1.     View: DBA_DETAIL_PRIVILEGES
drop VIEW DBA_DETAIL_PRIVILEGES CASCADE;
CREATE OR REPLACE VIEW DBA_DETAIL_PRIVILEGES
AS
SELECT *
  FROM (select oid, 'pg_default_acl' as oid_class
             , case defaclobjtype when 'r' then 'RELATION' when 'S' then 'SEQUENCE' when 'f' then 'FUNCTION' when 'T' then 'TYPE' when 'n' then 'SCHEMA' else defaclobjtype::text end as type
             , 'DEFAULT PRIVILEGES' as privilege_type
             , defaclrole::regrole::text as owner
             , defaclnamespace::regnamespace::text as schema
             , null::text as NAME
             , NULL::text as column_name
             , (aclexplode(defaclacl)).grantor::regrole::text AS grantor
             , (aclexplode(defaclacl)).grantee::regrole::text AS grantee
             , (aclexplode(defaclacl)).privilege_type AS privilege
             , (aclexplode(defaclacl)).is_grantable AS is_grantable
          from pg_default_acl
         where defaclacl is not null
         union all
        select oid, 'pg_class' as oid_class
             , case relkind when 'r' then 'TABLE' when 'S' then 'SEQUENCE' when 'v' then 'VIEW' when 'm' then 'MATERIALIZED VIEW' when 'f' then 'FOREIGN TABLE' when 'p' then 'PARTITIONED TABLE' else relkind::text end as type
             , case relkind when 'S' then 'SEQUENCE' else 'TABLE' end as privilege_type
             , relowner::regrole::text as owner
             , relnamespace::regnamespace::text as schema
             , relname::text as NAME
             , NULL::text as column_name
             , (aclexplode(relacl)).grantor::regrole::text AS grantor
             , (aclexplode(relacl)).grantee::regrole::text AS grantee
             , (aclexplode(relacl)).privilege_type AS privilege
             , (aclexplode(relacl)).is_grantable AS is_grantable
          from pg_class
         where relacl is not null
         union all
        select c.oid, 'pg_class' as oid_class
             , 'COLUMN' as type
             , 'TABLE (COLUMN)' as privilege_type
             , c.relowner::regrole::text as owner
             , c.relnamespace::regnamespace::text as schema
             , c.relname::text as name
             , a.attname::text as column_name
             , (aclexplode(a.attacl)).grantor::regrole::text AS grantor
             , (aclexplode(a.attacl)).grantee::regrole::text AS grantee
             , (aclexplode(a.attacl)).privilege_type AS privilege
             , (aclexplode(a.attacl)).is_grantable AS is_grantable
          from pg_attribute as a
          join pg_class as c on a.attrelid = c.oid
         where a.attacl is not null
         union all
        select oid, 'pg_database' as oid_class
             , 'DATABASE' as type
             , 'DATABASE' as privilege_type
             , datdba::regrole::text as owner
             , null::text as schema
             , datname::text as name
             , null::text as column_name
             , (aclexplode(datacl)).grantor::regrole::text AS grantor
             , (aclexplode(datacl)).grantee::regrole::text AS grantee
             , (aclexplode(datacl)).privilege_type AS privilege
             , (aclexplode(datacl)).is_grantable AS is_grantable
          from pg_database
         where datacl is not null
         union all
        select oid, 'pg_foreign_data_wrapper' as oid_class
             , 'FOREIGN DATA WRAPPER' as type
             , 'FOREIGN DATA WRAPPER' as privilege_type
             , fdwowner::regrole::text as owner
             , null::text as schema
             , fdwname::text as name
             , null::text as column_name
             , (aclexplode(fdwacl)).grantor::regrole::text AS grantor
             , (aclexplode(fdwacl)).grantee::regrole::text AS grantee
             , (aclexplode(fdwacl)).privilege_type AS privilege
             , (aclexplode(fdwacl)).is_grantable AS is_grantable
          from pg_foreign_data_wrapper
         where fdwacl is not null
         union all
        select oid, 'pg_foreign_server' as oid_class
             , 'FOREIGN SERVER' as type
             , 'FOREIGN SERVER' as privilege_type
             , srvowner::regrole::text as owner
             , null::text as schema
             , srvname::text as name
             , null::text as column_name
             , (aclexplode(srvacl)).grantor::regrole::text AS grantor
             , (aclexplode(srvacl)).grantee::regrole::text AS grantee
             , (aclexplode(srvacl)).privilege_type AS privilege
             , (aclexplode(srvacl)).is_grantable AS is_grantable
          from pg_foreign_server
         where srvacl is not null
         union all
        select oid, 'pg_type' as oid_class
             , case typtype when 'b' then 'BASE' when 'c' then 'COMPOSITE' when 'd' then 'DOMAIN' when 'e'  then 'ENUM' when 'p' then 'PSEUDO' when 'r' then 'RANGE' else typtype::text end as type
             , case typtype when 'd' then 'DOMAIN' else 'TYPE' end as privilege_type
             , typowner::regrole::text as owner
             , typnamespace::regnamespace::text as schema
             , typname::text as name
             , null::text as column_name
             , (aclexplode(typacl)).grantor::regrole::text AS grantor
             , (aclexplode(typacl)).grantee::regrole::text AS grantee
             , (aclexplode(typacl)).privilege_type AS privilege
             , (aclexplode(typacl)).is_grantable AS is_grantable
          from pg_type
         where typacl is not null
         union all
        select oid, 'pg_proc' as oid_class
             , case prokind when 'f' then 'FUNCTION' when 'p' then 'PROCEDURE' when 'a' then 'AGGREGATE' when 'w' then 'WINDOW' else prokind::text end as type
             , case prokind when 'p' then 'PROCEDURE' else 'FUNCTION' end as privilege_type
             , proowner::regrole::text as owner
             , pronamespace::regnamespace::text as schema
             , proname::text as name
             , null::text as column_name
             , (aclexplode(proacl)).grantor::regrole::text AS grantor
             , (aclexplode(proacl)).grantee::regrole::text AS grantee
             , (aclexplode(proacl)).privilege_type AS privilege
             , (aclexplode(proacl)).is_grantable AS is_grantable
          from pg_proc
         where proacl is not null
         union all
        select oid, 'pg_language' as oid_class
             , 'LANGUAGE' as type
             , 'LANGUAGE' as privilege_type
             , lanowner::regrole::text as owner
             , null::text as schema
             , lanname::text as name
             , null::text as column_name
             , (aclexplode(lanacl)).grantor::regrole::text AS grantor
             , (aclexplode(lanacl)).grantee::regrole::text AS grantee
             , (aclexplode(lanacl)).privilege_type AS privilege
             , (aclexplode(lanacl)).is_grantable AS is_grantable
          from pg_language
         where lanacl is not null
         union all
        select oid, 'pg_largeobject_metadata' as oid_class
             , 'LARGE OBJECT' as type
             , 'LARGE OBJECT' as privilege_type
             , lomowner::regrole::text as owner
             , null::text as schema
             , oid::text as name
             , null::text as column_name
             , (aclexplode(lomacl)).grantor::regrole::text AS grantor
             , (aclexplode(lomacl)).grantee::regrole::text AS grantee
             , (aclexplode(lomacl)).privilege_type AS privilege
             , (aclexplode(lomacl)).is_grantable AS is_grantable
          from pg_largeobject_metadata
         where lomacl is not null
         union all
        select oid, 'pg_namespace' as oid_class
             , 'SCHEMA' as type
             , 'SCHEMA' as privilege_type
             , nspowner::regrole::text as owner
             , null::text as schema
             , nspname::text as name
             , null::text as column_name
             , (aclexplode(nspacl)).grantor::regrole::text AS grantor
             , (aclexplode(nspacl)).grantee::regrole::text AS grantee
             , (aclexplode(nspacl)).privilege_type AS privilege
             , (aclexplode(nspacl)).is_grantable AS is_grantable
          from pg_namespace
         where nspacl is not null
         union all
        select oid, 'pg_tablespace' as oid_class
             , 'TABLESPACE' as type
             , 'TABLESPACE' as privilege_type
             , spcowner::regrole::text as owner
             , null::text as schema
             , spcname::text as name
             , null::text as column_name
             , (aclexplode(spcacl)).grantor::regrole::text AS grantor
             , (aclexplode(spcacl)).grantee::regrole::text AS grantee
             , (aclexplode(spcacl)).privilege_type AS privilege
             , (aclexplode(spcacl)).is_grantable AS is_grantable
          from pg_tablespace
         where spcacl is not null
       ) t
 where t.grantee != t.grantor
   and t.grantee != '-';


-- 2.     View: DBA_ALL_PRIVILEGES
drop VIEW DBA_ALL_PRIVILEGES CASCADE;
CREATE OR REPLACE VIEW DBA_ALL_PRIVILEGES
AS
with all_privs as (select oid, oid_class, type, privilege_type, owner, schema, name, column_name, grantor, grantee, is_grantable
                     from dba_detail_privileges
                    group by oid, oid_class, type, privilege_type, owner, schema, name, column_name, grantor, grantee, is_grantable
                   having (privilege_type = 'TABLE' and count(*) = 7)
                       or (privilege_type = 'TABLE (COLUMN)' and count(*) = 4)
                       or (privilege_type = 'SEQUENCE' and count(*) = 3)
                       or (privilege_type = 'DATABASE' and count(*) = 3)
                       or (privilege_type = 'LARGE OBJECT' and count(*) = 2)
                       or (privilege_type = 'SCHEMA' and count(*) = 2)
                       or (privilege_type = 'DEFAULT PRIVILEGES' and type = 'RELATION' and count(*) = 7)
                       or (privilege_type = 'DEFAULT PRIVILEGES' and type = 'SEQUENCE' and count(*) = 3)
                       or (privilege_type = 'DEFAULT PRIVILEGES' and type = 'SCHEMA' and count(*) = 2)
                  )
SELECT t.*
     , case when privilege_type = 'TABLE (COLUMN)'
            then 'GRANT '||privilege||' ('||column_name||') on TABLE '||schema||'.'||name||' to '||grantee
            when privilege_type = 'DEFAULT PRIVILEGES'
            then 'alter default privileges for user '||grantor||' GRANT '||privilege||' on '||(case type when 'RELATION' then 'TABLE' else type end)||'S to '||grantee
            else 'GRANT '||privilege||' on '||privilege_type||' '||(case when schema is not null then schema||'.'||name else name end)||' to '||grantee
       end as grant_sql
     , case when privilege_type = 'TABLE (COLUMN)'
            then 'REVOKE '||privilege||' ('||column_name||') on TABLE '||schema||'.'||name||' from '||grantee
            when privilege_type = 'DEFAULT PRIVILEGES'
            then 'alter default privileges for user '||grantor||' REVOKE '||privilege||' on '||(case type when 'RELATION' then 'TABLE' else type end)||'S from '||grantee
            else 'REVOKE '||privilege||' on '||privilege_type||' '||(case when schema is not null then schema||'.'||name else name end)||' from '||grantee
       end as revoke_sql
  from (select oid, oid_class, type, privilege_type, owner, schema, name, column_name, grantor, grantee, 'ALL' as privilege, is_grantable
          from all_privs
         union all
        select oid, oid_class, type, privilege_type, owner, schema, name, column_name, grantor, grantee, privilege, is_grantable
          from dba_detail_privileges x
         where not exists (select 1 from all_privs where oid = x.oid and grantor = x.grantor and grantee = x.grantee)
       ) t;


-- 3. Function: PG_DROP_USER_CASCADE
create or replace function PG_DROP_USER_CASCADE ( pi_user            text
                                                , pi_schema_cascade  boolean  default 'false')
returns void
as $$
declare
    l_record    record;
    l_user      text     := lower(pi_user);
    l_exists    bigint;
begin
    if pi_schema_cascade
    then
        raise notice '0. drop schemas: %', clock_timestamp();
        for l_record in select nspname::regnamespace::text as nspname
                          from pg_namespace
                         where nspowner = l_user::regrole
        loop
            raise notice '   drop schema if exists % cascade', l_record.nspname;
            execute 'drop schema if exists '||l_record.nspname||' cascade';
        end loop;
    end if;

    select count(*) into l_exists from pg_user where usename = l_user;
    if l_exists > 0 then
        raise notice '1. revoke privileges: %', clock_timestamp();
        for l_record in select 'revoke '||privilege||' on '||privilege_type||' '||(case when schema is not null then schema||'.'||name else name end)||' from '||grantee as revoke_sql
                          from dba_all_privileges
                         where privilege_type not in ('TABLE (COLUMN)', 'DEFAULT PRIVILEGES')
                           and (grantee = l_user or grantor = l_user or owner = l_user)
                         union all
                        select 'revoke '||privilege||' ('||string_agg(column_name, ',')||') on TABLE '||schema||'.'||name||' from '||grantee as revoke_sql
                          from dba_all_privileges
                         where privilege_type = 'TABLE (COLUMN)'
                           and (grantee = l_user or grantor = l_user or owner = l_user)
                         group by privilege, privilege_type, schema, name, grantee
                         union all
                        select 'alter default privileges for user '||grantor||' revoke '||privilege||' on '||(case type when 'RELATION' then 'TABLE' else type end)||'S from '||grantee as revoke_sql
                          from dba_all_privileges
                         where privilege_type = 'DEFAULT PRIVILEGES'
                           and (grantee = l_user or grantor = l_user or owner = l_user)
        loop
            execute l_record.revoke_sql;
        end loop;

        raise notice '2. drop user mappings: %', clock_timestamp();
        for l_record in select srvname::text as srvname from pg_foreign_server where oid in (select umserver from pg_user_mapping where umuser = l_user::regrole)
        loop
            raise notice '   drop user mapping if exists for % server %', l_user, l_record.srvname;
            execute 'drop user mapping if exists for '||l_user||' server '||l_record.srvname;
        end loop;

        raise notice '3. drop user: %', clock_timestamp();
        raise notice '   drop user %', l_user;
        execute 'drop user '||l_user;
    end if;
end;
$$ language plpgsql;
