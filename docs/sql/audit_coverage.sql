-- docs/sql/audit_coverage.sql
create or replace view public.v_audit_trigger_coverage as
select c.relname as table_name,
       exists(
         select 1 from pg_trigger t
         where t.tgrelid=c.oid and t.tgenabled='O' and t.tgname like 'tr_audit_%'
       ) as has_audit_trigger
from pg_class c
join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relkind='r';
