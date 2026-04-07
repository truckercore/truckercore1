-- 996_rls_audit.sql
-- List user tables with RLS status
create or replace view public.rls_audit as
select
  n.nspname as schema,
  c.relname as table,
  c.relrowsecurity as rls_enabled
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind = 'r'
  and c.relname not like 'pg_%'
  and c.relname not like 'sql_%';

-- Emit an alert if any RLS is off
-- Requires: public.alert_outbox table with columns (key text, payload jsonb)
create or replace function public.check_rls_audit()
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.alert_outbox(key, payload)
  select 'rls_missing', jsonb_build_object('table', table)
  from public.rls_audit
  where rls_enabled = false;
$$;
