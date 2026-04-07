-- 20250924_runbook_reports_and_integrations.sql
-- Purpose: Runbook artifacts registry + integrations presence schema + sample state tables
--          and metrics views per issue. Idempotent and safe to re-run.

-- 1) Runbook artifacts registry ------------------------------------------------
create table if not exists public.runbook_reports (
  id uuid primary key default gen_random_uuid(),
  org_id uuid null,
  created_at timestamptz not null default now(),
  filename_txt text not null,
  filename_json text not null,
  summary jsonb not null,           -- {exit_code, ok, fail, duration_ms, git_sha, tz}
  steps jsonb not null,             -- array of {name,status,duration_ms,remediation}
  status text not null check (status in ('ok','fail')),
  meta jsonb not null default '{}'::jsonb
);
create index if not exists idx_runbook_reports_time on public.runbook_reports (created_at desc);

alter table public.runbook_reports enable row level security;
create policy if not exists runbook_reports_read_org on public.runbook_reports
for select to authenticated
using (org_id is null or org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

-- 2) Integrations schema + presence tables ------------------------------------
create schema if not exists integrations;

create table if not exists integrations.provider_accounts (
  id uuid primary key default gen_random_uuid(),
  provider text not null,
  org_id uuid null,
  external_id text not null,
  created_at timestamptz not null default now(),
  unique (provider, external_id)
);

create table if not exists integrations.sync_jobs (
  id uuid primary key default gen_random_uuid(),
  provider text not null,
  org_id uuid null,
  job_type text not null,
  status text not null check (status in ('queued','running','success','failed','partial')),
  started_at timestamptz null,
  finished_at timestamptz null,
  stats jsonb not null default '{}'::jsonb,
  error text null,
  created_at timestamptz not null default now()
);

-- 3) Sample public tables (presence verified by runbook) ----------------------
create table if not exists public.vehicle_positions (
  id bigserial primary key,
  vehicle_id uuid not null,
  lat double precision not null,
  lng double precision not null,
  speed_kph double precision null,
  gps_ts timestamptz not null
);

create table if not exists public.driver_status (
  driver_user_id uuid primary key,
  status text not null check (status in ('driving','on_duty','off_duty','sleeper')),
  updated_at timestamptz not null default now()
);

-- 4) Views for current state ---------------------------------------------------
create or replace view public.v_vehicle_positions_current as
select distinct on (vehicle_id)
  vehicle_id, lat, lng, speed_kph, gps_ts
from public.vehicle_positions
order by vehicle_id, gps_ts desc;

create or replace view public.v_driver_current_status as
select driver_user_id, status, updated_at
from public.driver_status;

-- 5) Metrics views for alerts --------------------------------------------------
-- v_sso_failure_rate_24h (guard if source table exists)
DO $$
BEGIN
  IF to_regclass('public.sso_health') IS NOT NULL THEN
    EXECUTE $$
      create or replace view public.v_sso_failure_rate_24h as
      select
        org_id,
        sum(attempts_24h)::int as attempts_24h,
        sum(failures_24h)::int as failures_24h,
        case when sum(attempts_24h) > 0 then (sum(failures_24h)::numeric / sum(attempts_24h)) else 0 end as failure_rate_24h
      from public.sso_health
      group by org_id;
    $$;
  ELSE
    EXECUTE $$
      create or replace view public.v_sso_failure_rate_24h as
      select cast(null as uuid) as org_id, 0::int as attempts_24h, 0::int as failures_24h, 0::numeric as failure_rate_24h
      where false;
    $$;
  END IF;
END $$;

-- v_scim_runs_24h (guard if scim_audit exists)
DO $$
BEGIN
  IF to_regclass('public.scim_audit') IS NOT NULL THEN
    EXECUTE $$
      create or replace view public.v_scim_runs_24h as
      select
        org_id,
        count(*) filter (where status='success') as ok_runs,
        count(*) filter (where status in ('failed','partial')) as bad_runs
      from public.scim_audit
      where run_started_at >= now() - interval '24 hours'
      group by org_id;
    $$;
  ELSE
    EXECUTE $$
      create or replace view public.v_scim_runs_24h as
      select cast(null as uuid) as org_id, 0::bigint as ok_runs, 0::bigint as bad_runs
      where false;
    $$;
  END IF;
END $$;

-- 6) RPC posture quick-check helper (view over pg_catalog) --------------------
create or replace view public.v_rpc_security_posture as
select
  p.proname,
  p.prosecdef as security_definer,
  n.nspname as schema
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname in ('public','rpc','integrations');
