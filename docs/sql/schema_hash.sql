-- docs/sql/schema_hash.sql
create or replace view public.v_schema_hash as
select md5(string_agg(ddl, '' order by kind, ddl)) as hash
from (
  select 'function'::text as kind, pg_get_functiondef(p.oid) as ddl
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public'
  union all
  select 'view', pg_get_viewdef(c.oid)
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relkind='v'
  union all
  select 'table', pg_get_tabledef(c.oid)
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relkind='r'
) defs;
