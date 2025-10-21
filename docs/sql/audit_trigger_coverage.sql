-- docs/sql/audit_trigger_coverage.sql
-- Lists public tables that have audit triggers attached for INSERT/UPDATE/DELETE operations
-- Used by CI gate to ensure no table changes without audit coverage

create or replace view public.audit_trigger_coverage as
with tbls as (
  select c.oid as relid, c.relname
  from pg_class c
  join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relkind='r'
),
trgs as (
  select t.tgrelid as relid,
         string_agg(distinct t.tgtype::int::bit(8)::text, ',') as tgtypes,
         bool_or(p.proname = 'log_row_change') as uses_logger,
         array_agg(distinct case when (t.tgtype & 4) <> 0 then 'INSERT' end) as has_insert,
         array_agg(distinct case when (t.tgtype & 8) <> 0 then 'DELETE' end) as has_delete,
         array_agg(distinct case when (t.tgtype & 16) <> 0 then 'UPDATE' end) as has_update
  from pg_trigger t
  join pg_proc p on p.oid = t.tgfoid
  where not t.tgisinternal
  group by t.tgrelid
)
select 
  tbls.relname as table_name,
  coalesce(uses_logger, false) as uses_logger,
  (array_position(has_insert, 'INSERT') is not null) as on_insert,
  (array_position(has_update, 'UPDATE') is not null) as on_update,
  (array_position(has_delete, 'DELETE') is not null) as on_delete
from tbls
left join trgs using (relid);
