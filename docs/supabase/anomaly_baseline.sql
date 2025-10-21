-- docs/supabase/anomaly_baseline.sql
-- Anomaly baseline table and weekly z-score backfill for SSO failure rate.
-- Also defines a daily failure-rate view derived from public.sso_events.
-- Idempotent and safe to re-run.

create extension if not exists pgcrypto;

-- 1) Baseline table
create table if not exists public.anomaly_baseline (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  metric text not null,               -- e.g., 'sso_failure_rate'
  week_start date not null,           -- date_trunc('week', now())
  mean numeric not null,
  stddev numeric not null,
  zscore numeric not null,
  samples int not null,
  created_at timestamptz not null default now(),
  unique (org_id, metric, week_start)
);

alter table public.anomaly_baseline enable row level security;
DO $$ BEGIN
  DROP POLICY IF EXISTS anomaly_baseline_read_org ON public.anomaly_baseline;
  CREATE POLICY anomaly_baseline_read_org ON public.anomaly_baseline
  FOR SELECT TO authenticated
  USING (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
END $$;

-- 2) Daily SSO failure rate view based on sso_events (success/error outcomes)
create or replace view public.v_sso_failure_rate_daily as
select
  org_id,
  date_trunc('day', ts)::date as ts,
  case when count(*) = 0 then null
       else (count(*) filter (where outcome='error')::numeric / nullif(count(*),0))
  end as failure_rate
from public.sso_events
where ts >= now() - interval '90 days'
group by org_id, date_trunc('day', ts)::date;

-- 3) Backfill last 12 weeks for metric 'sso_failure_rate'
with weekly as (
  select
    org_id,
    date_trunc('week', ts)::date as week_start,
    avg(failure_rate) as week_rate,
    count(*) as samples
  from public.v_sso_failure_rate_daily
  where ts >= current_date - interval '84 days'
  group by 1,2
),
stats as (
  select
    org_id,
    'sso_failure_rate'::text as metric,
    week_start,
    week_rate,
    avg(week_rate) over (partition by org_id) as mean,
    stddev_pop(week_rate) over (partition by org_id) as stddev,
    samples
  from weekly
)
insert into public.anomaly_baseline (org_id, metric, week_start, mean, stddev, zscore, samples)
select
  org_id,
  metric,
  week_start,
  coalesce(mean, 0),
  coalesce(stddev, 0),
  case when coalesce(stddev,0) > 0 then (week_rate - mean)/stddev else 0 end as zscore,
  samples
from stats
on conflict (org_id, metric, week_start) do update
set mean = excluded.mean,
    stddev = excluded.stddev,
    zscore = excluded.zscore,
    samples = excluded.samples,
    created_at = now();
