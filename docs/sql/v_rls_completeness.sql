-- docs/sql/v_rls_completeness.sql
-- Evidence view to check RLS enablement and presence of policies per public table
create or replace view public.v_rls_completeness as
select
  c.relname as table_name,
  c.relrowsecurity as rls_enabled,
  exists (
    select 1 from pg_policies p
    where p.schemaname='public' and p.tablename=c.relname
  ) as has_policies
from pg_class c
join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relkind='r';
