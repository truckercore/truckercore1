-- docs/supabase/alerts_reporting.sql
-- Alert reporting helpers: weekly first/last seen, MTTA/MTTR, snooze severity tweak, remediation click tracking.
-- Idempotent and safe to re-run.

create extension if not exists pgcrypto;

-- 1) Weekly first_seen / last_seen per alert code (7 days)
--   Source table expected: public.alerts_events(org_id uuid, code text, severity text, triggered_at timestamptz, acknowledged boolean default false, acknowledged_at timestamptz null, resolved_at timestamptz null, last_error_code text null)
create or replace view public.v_alerts_first_last_7d as
with windowed as (
  select org_id, code, severity, triggered_at
  from public.alerts_events
  where triggered_at >= now() - interval '7 days'
),
Bounds as (
  select org_id, code,
         min(triggered_at) as first_seen,
         max(triggered_at) as last_seen,
         count(*) as occurrences
  from windowed
  group by org_id, code
),
sev_latest as (
  select distinct on (org_id, code) org_id, code, severity, triggered_at
  from windowed
  order by org_id, code, triggered_at desc
)
select b.org_id,
       b.code,
       b.first_seen,
       b.last_seen,
       b.occurrences,
       sl.severity as last_severity
from Bounds b
left join sev_latest sl using (org_id, code)
order by b.org_id, b.code;

-- 2) MTTA/MTTR by code (7 days)
create or replace view public.v_alerts_mtta_mttr_7d as
with week as (
  select * from public.alerts_events
  where triggered_at >= now() - interval '7 days'
),
calc as (
  select
    org_id,
    code,
    avg(extract(epoch from (acknowledged_at - triggered_at)) / 60.0) filter (where acknowledged) as mtta_min,
    avg(extract(epoch from (resolved_at - triggered_at)) / 60.0) filter (where resolved_at is not null) as mttr_min
  from week
  group by org_id, code
)
select * from calc order by org_id, code;

-- 3) MTTA/MTTR monthly trend (last 12 months)
create or replace view public.v_alerts_mtta_mttr_monthly_12mo as
select date_trunc('month', triggered_at) as month,
       org_id,
       code,
       avg(extract(epoch from (acknowledged_at - triggered_at))/60.0) filter (where acknowledged) as mtta_min,
       avg(extract(epoch from (resolved_at - triggered_at))/60.0) filter (where resolved_at is not null) as mttr_min
from public.alerts_events
where triggered_at >= now() - interval '12 months'
group by 1,2,3
order by 1,2,3;

-- 4) Optional: root-cause aggregation (last 90 days)
create or replace view public.v_alert_root_causes_90d as
select code, last_error_code, count(*) as occurrences
from public.alerts_events
where triggered_at >= now() - interval '90 days'
group by 1,2
order by occurrences desc;

-- 5) Snooze schema tweak: store severity at set time to allow auto-unsnooze on escalation
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' and table_name='alert_snooze' and column_name='severity_at_set'
  ) THEN
    EXECUTE $$
      ALTER TABLE public.alert_snooze
        ADD COLUMN severity_at_set text not null default 'WARN' check (severity_at_set in ('INFO','WARN','P2','P1','P0'))
    $$;
  END IF;
END $$;

-- 6) Remediation clicks logging
create table if not exists public.remediation_clicks (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  code text not null,      -- e.g., 'SSO_FAIL_RATE', 'SCIM_FAIL'
  action text not null,    -- e.g., 'sso_selfcheck', 'scim_dryrun'
  clicked_at timestamptz not null default now()
);
create index if not exists idx_remediation_clicks_org_time on public.remediation_clicks (org_id, clicked_at desc);

-- 7) Convenience: top remediation actions in last quarter
create or replace view public.v_remediation_clicks_top_90d as
select action, count(*) as clicks
from public.remediation_clicks
where clicked_at >= now() - interval '90 days'
group by 1
order by clicks desc;

-- 8) Alerts events canonical source (if missing)
-- Drives first/last seen, MTTA/MTTR, and escalation audit trail
create table if not exists public.alerts_events (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  code text not null,
  severity text not null check (severity in ('INFO','WARN','P2','P1','P0')),
  triggered_at timestamptz not null default now(),
  acknowledged boolean not null default false,
  acknowledged_at timestamptz null,
  resolved_at timestamptz null,
  last_error_code text null,
  event text null -- e.g., 'escalation_logged'
);
create index if not exists idx_alerts_events_org_code_time on public.alerts_events(org_id, code, triggered_at desc);
alter table public.alerts_events enable row level security;
DO $$ BEGIN
  DROP POLICY IF EXISTS alerts_events_read_org ON public.alerts_events;
  CREATE POLICY alerts_events_read_org ON public.alerts_events
  FOR SELECT TO authenticated
  USING (org_id::text = public.jwt_claim('app_org_id'));
END $$;

-- 9) Remediation clicks: add outcome and latency_ms for ranking effectiveness
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' and table_name='remediation_clicks' and column_name='outcome'
  ) THEN
    EXECUTE 'ALTER TABLE public.remediation_clicks ADD COLUMN outcome text null';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' and table_name='remediation_clicks' and column_name='latency_ms'
  ) THEN
    EXECUTE 'ALTER TABLE public.remediation_clicks ADD COLUMN latency_ms int null';
  END IF;
END $$;
