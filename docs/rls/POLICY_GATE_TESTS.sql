-- POLICY_GATE_TESTS.sql
-- Purpose: Quick manual/CI assertions for RLS policy gating.
-- Usage: psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f docs/rls/POLICY_GATE_TESTS.sql

-- 1) Expect critical tables to have RLS enabled
select relname as table, relrowsecurity as rls_enabled
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and relkind='r'
  and relname in ('alerts_events','hos_logs','metrics_events')
order by relname;

-- 2) Policies present (names may vary)
select polname, relname, polcmd from pg_policies where schemaname='public' and relname='alerts_events';
select polname, relname, polcmd from pg_policies where schemaname='public' and relname='hos_logs';

-- 3) Optional: function visibility
-- select has_function_privilege('public.ifta_quarter_csv(uuid,date)','execute');
