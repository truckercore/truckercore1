-- 20250924_sso_metrics_and_views.sql
-- Purpose: SSO/self-check metrics schema, health views, materialized views with CONCURRENTLY-safe indexes,
-- admin function-privileges view, and a server-only helper RPC to log 429 self-checks.
-- All statements are idempotent and safe to re-run in Supabase.

-- ========== Metrics tables (append-only counters; written by Edge/jobs) ==========
create table if not exists public.metric_sso_attempts (
  ts timestamptz not null default now(),
  org_id uuid not null,
  idp text not null,
  success boolean not null
);
create index if not exists idx_metric_sso_attempts_time on public.metric_sso_attempts (ts desc);
create index if not exists idx_metric_sso_attempts_org on public.metric_sso_attempts (org_id, ts desc);

alter table public.metric_sso_attempts enable row level security;
-- Org-scoped read for authenticated users
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='metric_sso_attempts' AND policyname='metric_sso_attempts_read_org'
  ) THEN
    CREATE POLICY metric_sso_attempts_read_org ON public.metric_sso_attempts
    FOR SELECT TO authenticated
    USING (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
  END IF;
END $$;
-- writes via service-role/jobs only
REVOKE INSERT, UPDATE, DELETE ON public.metric_sso_attempts FROM authenticated;

create table if not exists public.metric_selfcheck_429 (
  ts timestamptz not null default now(),
  org_id uuid not null
);
create index if not exists idx_metric_selfcheck_429 on public.metric_selfcheck_429 (org_id, ts desc);

alter table public.metric_selfcheck_429 enable row level security;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='metric_selfcheck_429' AND policyname='metric_selfcheck_429_read_org'
  ) THEN
    CREATE POLICY metric_selfcheck_429_read_org ON public.metric_selfcheck_429
    FOR SELECT TO authenticated
    USING (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
  END IF;
END $$;
REVOKE INSERT, UPDATE, DELETE ON public.metric_selfcheck_429 FROM authenticated;

-- ========== Views: SSO 24h failure rate; Self-check 429 rate (15m) ==========
create or replace view public.v_sso_failure_rate_24h as
select
  m.org_id,
  count(*) filter (where m.ts >= now() - interval '24 hours') as attempts_24h,
  count(*) filter (where m.ts >= now() - interval '24 hours' and m.success = false) as failures_24h,
  case
    when count(*) filter (where m.ts >= now() - interval '24 hours') = 0 then null
    else count(*) filter (where m.ts >= now() - interval '24 hours' and m.success = false)::numeric
         / count(*) filter (where m.ts >= now() - interval '24 hours')
  end as failure_rate_24h
from public.metric_sso_attempts m
group by m.org_id;

ALTER VIEW public.v_sso_failure_rate_24h OWNER TO postgres;
GRANT SELECT ON public.v_sso_failure_rate_24h TO authenticated, anon;

create or replace view public.v_selfcheck_429_15m as
select org_id, count(*) as hits_15m
from public.metric_selfcheck_429
where ts >= now() - interval '15 minutes'
group by org_id;

GRANT SELECT ON public.v_selfcheck_429_15m TO authenticated, anon;

-- ========== Materialized views and refresh safety ==========
-- Example MVs (replace bodies with your queries as needed)
create materialized view if not exists public.mv_daily_truck_stats as
select date_trunc('day', ts)::date as day, org_id, count(*) as events
from public.metric_sso_attempts
group by 1,2;

-- Unique index required for CONCURRENTLY
create unique index if not exists uidx_mv_daily_truck_stats on public.mv_daily_truck_stats (day, org_id);

create materialized view if not exists public.mv_daily_org_stats as
select date_trunc('day', ts)::date as day, org_id,
       count(*) filter (where success) as sso_ok,
       count(*) filter (where not success) as sso_fail
from public.metric_sso_attempts
group by 1,2;

create unique index if not exists uidx_mv_daily_org_stats on public.mv_daily_org_stats (day, org_id);

-- RLS is not typically enabled on MVs; grant read access
GRANT SELECT ON public.mv_daily_truck_stats, public.mv_daily_org_stats TO authenticated, anon;

-- ========== Administration / Security checks ==========
-- Functions executable with RLS context: list security definer/public grants
create or replace view public.v_fn_privs as
select n.nspname as schema, p.proname as function, p.prosecdef as security_definer, p.proacl
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname in ('public','billing') and p.proacl is not null;

GRANT SELECT ON public.v_fn_privs TO authenticated, anon;

-- ========== Optional: Server-side 429 logger (service-only) ==========
create or replace function public.fn_log_selfcheck_429(p_org_id uuid)
returns void language sql security definer as $$
  insert into public.metric_selfcheck_429(org_id) values (p_org_id);
$$;
REVOKE ALL ON FUNCTION public.fn_log_selfcheck_429(uuid) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_log_selfcheck_429(uuid) TO service_role;
