-- 20250924_e2e_metrics_views.sql
-- Purpose: Quick dashboard views for E2E outcomes, pass rates, DB lifecycle health, fail hotspots, and mock call volume.
-- Safe to re-run (create or replace).

-- Last 7 days e2e outcome
create or replace view public.v_e2e_outcomes_7d as
select
  suite, project, env,
  count(*) as runs,
  sum(case when status='passed' then 1 else 0 end) as passed,
  sum(case when status='failed' then 1 else 0 end) as failed,
  sum(case when status='flaky' then 1 else 0 end) as flaky,
  round(avg(duration_ms))::int as avg_duration_ms
from public.e2e_runs
where created_at >= now() - interval '7 days'
group by 1,2,3;

-- Playwright project pass rate (7d)
create or replace view public.v_playwright_pass_rate as
select
  project,
  1.0 * sum(case when status='passed' then 1 else 0 end) / nullif(count(*),0) as pass_rate,
  sum(specs_total) as specs_total_sum,
  sum(specs_failed) as specs_failed_sum
from public.e2e_runs
where suite='playwright' and created_at >= now() - interval '7 days'
group by 1;

-- Test DB lifecycle health (7d)
create or replace view public.v_test_db_health_7d as
select
  env,
  count(*) as runs,
  sum(case when status='ok' then 1 else 0 end) as ok,
  sum(case when status='error' then 1 else 0 end) as errors,
  round(avg(duration_ms))::int as avg_duration_ms
from public.test_db_runs
where created_at >= now() - interval '7 days'
group by 1;

-- Top failing specs/projects (placeholder using runs aggregate)
create or replace view public.v_e2e_fail_hotspots as
select project, count(*) as failures
from public.e2e_runs
where status='failed' and created_at >= now() - interval '7 days'
group by 1
order by failures desc;

-- Mock call volume (24h)
create or replace view public.v_mock_calls_24h as
select source, count(*) as calls
from public.mock_calls
where ts >= now() - interval '24 hours'
group by 1;
