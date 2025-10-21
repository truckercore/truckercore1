-- docs/supabase/anomaly_alerts.sql
-- Anomaly alerts base schema and views. Idempotent and safe to re-run.
-- Provides:
--  - endpoint_events (org_id, occurred_at, status)
--  - analytics_snapshots (id, org_id, version, payload, updated_at)
--  - v_pass_daily, v_pass_wow
--  - v_snapshot_volume_3sigma
--  - v_failures_by_code_7d, v_recent_fail_samples

create extension if not exists pgcrypto;

-- 0) Minimal endpoint events table if not present (status in 'success'|'error')
DO $$ BEGIN
  IF to_regclass('public.endpoint_events') IS NULL THEN
    EXECUTE $$
      create table public.endpoint_events (
        id uuid primary key default gen_random_uuid(),
        org_id uuid not null,
        occurred_at timestamptz not null default now(),
        code text null,
        status text not null check (status in ('success','error')),
        meta jsonb not null default '{}'::jsonb
      )
    $$;
  END IF;
END $$;

-- 1) Minimal analytics_snapshots table if not present (stores latest per org)
DO $$ BEGIN
  IF to_regclass('public.analytics_snapshots') IS NULL THEN
    EXECUTE $$
      create table public.analytics_snapshots (
        id uuid primary key default gen_random_uuid(),
        org_id uuid not null,
        version int not null default 1,
        etag text null,
        payload jsonb not null default '{}'::jsonb,
        updated_at timestamptz not null default now()
      )
    $$;
    CREATE INDEX IF NOT EXISTS idx_analytics_snapshots_org_time ON public.analytics_snapshots(org_id, updated_at desc);
  END IF;
END $$;

-- 2) Daily pass stats (success/attempts) per org
create or replace view public.v_pass_daily as
select
  org_id,
  date_trunc('day', occurred_at)::date as day,
  count(*) filter (where status = 'success')::int as successes,
  count(*)::int as attempts,
  case when count(*)=0 then 0::numeric
       else round(count(*) filter (where status='success')::numeric / count(*)::numeric, 4)
  end as pass_rate
from public.endpoint_events
group by 1,2;

-- 3) Week-over-week compare (current 7d vs prior 7d)
create or replace view public.v_pass_wow as
with curr as (
  select org_id, round(avg(pass_rate), 4) as pass_rate_curr
  from public.v_pass_daily
  where day >= current_date - 7
  group by org_id
),
prev as (
  select org_id, round(avg(pass_rate), 4) as pass_rate_prev
  from public.v_pass_daily
  where day >= current_date - 14 and day < current_date - 7
  group by org_id
)
select
  coalesce(curr.org_id, prev.org_id) as org_id,
  curr.pass_rate_curr,
  prev.pass_rate_prev,
  round(coalesce(curr.pass_rate_curr,0) - coalesce(prev.pass_rate_prev,0), 4) as delta
from curr full outer join prev using (org_id);

-- 4) Snapshot volume ±3σ from 30-day mean
create or replace view public.v_snapshot_volume_3sigma as
with daily as (
  select
    org_id,
    date_trunc('day', updated_at)::date as day,
    count(*)::int as snapshots
  from public.analytics_snapshots
  where updated_at >= now() - interval '30 days'
  group by 1,2
),
stats as (
  select
    org_id,
    avg(snapshots)::numeric as mean,
    stddev_pop(snapshots)::numeric as sigma
  from daily
  group by org_id
),
today as (
  select org_id, sum(snapshots)::int as today_count
  from daily
  where day = current_date
  group by org_id
)
select
  s.org_id,
  s.mean, s.sigma, coalesce(t.today_count,0) as today_count,
  case when s.sigma is null or s.sigma = 0 then false
       else (coalesce(t.today_count,0) > s.mean + 3*s.sigma) or (coalesce(t.today_count,0) < greatest(s.mean - 3*s.sigma,0))
  end as is_outlier
from stats s
left join today t on t.org_id = s.org_id;

-- 5) Drill-down views
-- Top failures by code (7d)
create or replace view public.v_failures_by_code_7d as
select
  org_id,
  coalesce(code,'unknown') as code,
  count(*) filter (where status='error')::int as failures,
  round(count(*) filter (where status='error')::numeric / nullif(count(*),0), 4) as critical_ratio
from public.endpoint_events
where occurred_at >= now() - interval '7 days'
group by 1,2
order by failures desc
limit 10;

-- Recent failure samples (redacted payload if available)
DO $$ BEGIN
  IF to_regclass('public.alerts_events') IS NULL THEN
    -- Fallback to endpoint_events if alerts_events not available
    EXECUTE $$
      create or replace view public.v_recent_fail_samples as
      select org_id, coalesce(code,'unknown') as code, 'WARN'::text as severity, occurred_at as triggered_at,
             '{}'::jsonb as context
      from public.endpoint_events
      where status='error' and occurred_at >= now() - interval '24 hours'
      order by occurred_at desc
      limit 200
    $$;
  ELSE
    EXECUTE $$
      create or replace view public.v_recent_fail_samples as
      select
        org_id,
        code,
        severity,
        triggered_at,
        jsonb_strip_nulls(payload - 'pii' - 'secrets') as context
      from public.alerts_events
      where triggered_at >= now() - interval '24 hours'
      order by triggered_at desc
      limit 200
    $$;
  END IF;
END $$;

-- 6) RLS guidance (read-only by org); adjust as needed
ALTER TABLE IF EXISTS public.endpoint_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.analytics_snapshots ENABLE ROW LEVEL SECURITY;

-- Example RLS (org-scoped SELECT); writes via service roles
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'jwt_claim' AND pronamespace = 'public'::regnamespace) THEN
    EXECUTE $$ create or replace function public.jwt_claim(claim text) returns text stable language sql as $$ select coalesce(current_setting('request.jwt.claims', true)::json->>claim, '') $$ $$; $$;
  END IF;
END $$;

DO $$ BEGIN
  DROP POLICY IF EXISTS endpoint_events_read ON public.endpoint_events;
  CREATE POLICY endpoint_events_read ON public.endpoint_events FOR SELECT TO authenticated USING (org_id::text = public.jwt_claim('app_org_id'));
EXCEPTION WHEN undefined_table THEN NULL; END $$;

DO $$ BEGIN
  DROP POLICY IF EXISTS analytics_snapshots_read ON public.analytics_snapshots;
  CREATE POLICY analytics_snapshots_read ON public.analytics_snapshots FOR SELECT TO authenticated USING (org_id::text = public.jwt_claim('app_org_id'));
EXCEPTION WHEN undefined_table THEN NULL; END $$;
