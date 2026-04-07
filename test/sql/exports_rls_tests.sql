-- test/sql/exports_rls_tests.sql
-- Requires pgTAP installed in CI DB
BEGIN;
SELECT plan(4);

-- 1) View exists
SELECT has_view('public', 'v_export_alerts', 'v_export_alerts exists');

-- 2) RLS on core tables enabled
SELECT results_eq(
  $$select count(1) from pg_tables where schemaname='public' and tablename in ('driver_profiles','crowd_reports','alert_events') and relrowsecurity=true$$,
  $$select 3$$,
  'RLS enabled on core tables'
);

-- 3) Function exists
SELECT has_function('public', 'refresh_safety_summary', ARRAY['uuid','integer'], 'refresh_safety_summary exists');

-- 4) Anonymous select on v_export_alerts allowed (schema grants)
SELECT ok(
  (select has_table_privilege('anon', 'public.v_export_alerts', 'SELECT')),
  'anon has select on v_export_alerts'
);

SELECT finish();
ROLLBACK;
