-- RLS Assertions for recently touched tables/views
-- Run in SQL editor or via CI with SUPABASE_DB_URL set.

-- 1) Ensure RLS is enabled on critical tables
select relname as table, relrowsecurity as rls_enabled
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname='public' and relkind='r'
  and relname in (
    'metrics_events',
    'analytics_snapshots',
    'ownerop_expenses',
    'hos_logs',
    'inspection_reports',
    'alerts_events'
  );

-- 2) Policy presence checks (names may differ; adapt as needed)
-- HOS logs: driver can read own org; fleet_manager role can read within org
select polname, relname, polcmd from pg_policies where schemaname='public' and relname='hos_logs';

-- Alerts events: org-scoped read/update (ack) policies
select polname, relname, polcmd from pg_policies where schemaname='public' and relname='alerts_events';

-- Metrics events: verify table exists and is RLS-protected; writes should be via service role or controlled RPCs
select to_regclass('public.metrics_events') as metrics_events_exists, (
  select relrowsecurity from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname='public' and c.relname='metrics_events'
) as metrics_events_rls;

-- 3) JWT claim mapping (manual):
-- Expect app_org_id in current_setting('request.jwt.claims', true)::json->>'app_org_id'
-- Expect sub claim for user id; roles in app_roles array.
-- Use: select current_setting('request.jwt.claims', true);

-- 4) Views touched (read-only): ensure RLS is applied on underlying tables
-- Example: select from metrics_events_daily and metrics_events_top_24h with anon to validate visibility.
