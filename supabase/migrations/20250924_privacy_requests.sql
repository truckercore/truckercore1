-- 20250924_privacy_requests.sql
-- Purpose: Privacy request metrics schema, optional org API keys, route rate-limit log, and reporting views.
-- Safe to re-run (idempotent) and aligned with org-scoped RLS patterns used in this repo.

-- ========== 1) Request metrics (privacy endpoints) ==========
create table if not exists public.privacy_requests (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  route text not null,              -- '/privacy/redacted', '/privacy/access-audit.csv'
  method text not null,
  ip inet null,
  user_id uuid null,
  status int not null,
  duration_ms int not null,
  rate_limited boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists idx_privacy_requests_org_time on public.privacy_requests (org_id, created_at desc);
create index if not exists idx_privacy_requests_route_time on public.privacy_requests (route, created_at desc);

alter table public.privacy_requests enable row level security;
-- Org-scoped read for authenticated users
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='privacy_requests' AND policyname='privacy_requests_read_org'
  ) THEN
    CREATE POLICY privacy_requests_read_org ON public.privacy_requests
    FOR SELECT TO authenticated
    USING (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
  END IF;
END$$;
-- Writes via service role only; ensure no default DML grants to authenticated
REVOKE INSERT, UPDATE, DELETE ON public.privacy_requests FROM authenticated, anon;

-- ========== 2) Org API keys (optional org-scoped rate keys) ==========
create table if not exists public.org_api_keys (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  key_hash text not null,                 -- store hash only if used
  scope text[] not null default '{}',
  created_at timestamptz not null default now(),
  disabled boolean not null default false
);
create index if not exists idx_org_api_keys_org on public.org_api_keys (org_id);

alter table public.org_api_keys enable row level security;
-- Read restricted to org members with corp_admin role in JWT app_roles array claim
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='org_api_keys' AND policyname='org_api_keys_read_admin'
  ) THEN
    CREATE POLICY org_api_keys_read_admin ON public.org_api_keys
    FOR SELECT TO authenticated
    USING (
      org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','')
      AND (coalesce(current_setting('request.jwt.claims', true)::json->'app_roles','[]'::json) ? 'corp_admin')
    );
  END IF;
END$$;
REVOKE INSERT, UPDATE, DELETE ON public.org_api_keys FROM authenticated, anon;

-- ========== 3) Function rate limits (keyed per org/route) ==========
create table if not exists public.route_rate_limits (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  route text not null,
  ip inet null,
  created_at timestamptz not null default now()
);
create index if not exists idx_route_limits_composite on public.route_rate_limits (org_id, route, created_at desc);

-- ========== 4) Supabase metrics views (privacy requests) ==========
-- Success/error rates per route (24h)
create or replace view public.v_privacy_route_stats_24h as
select
  org_id,
  route,
  count(*) as requests_24h,
  sum((status between 200 and 299)::int) as ok_24h,
  sum((status >= 400)::int) as errors_24h,
  round(coalesce(sum((status >= 400)::int)::numeric / nullif(count(*),0),0), 4) as error_rate_24h,
  round(avg(duration_ms)::numeric, 1) as avg_ms_24h,
  sum(rate_limited::int) as rate_limited_24h
from public.privacy_requests
where created_at >= now() - interval '24 hours'
group by org_id, route;

-- P95 latency per route (24h)
create or replace view public.v_privacy_route_p95_24h as
select org_id, route,
  percentile_cont(0.95) within group (order by duration_ms)::int as p95_ms_24h
from public.privacy_requests
where created_at >= now() - interval '24 hours'
group by org_id, route;

-- Top rate-limited IPs (24h)
create or replace view public.v_privacy_rate_limited_ips_24h as
select org_id, route, ip, count(*) as rl_hits_24h
from public.privacy_requests
where rate_limited = true and created_at >= now() - interval '24 hours'
group by org_id, route, ip
order by rl_hits_24h desc;

-- First/last seen per route (7d) for trend
create or replace view public.v_privacy_route_bounds_7d as
with w as (
  select org_id, route, created_at from public.privacy_requests
  where created_at >= now() - interval '7 days'
)
select org_id, route,
  min(created_at) as first_seen,
  max(created_at) as last_seen,
  count(*) as occurrences
from w group by org_id, route;

-- ========== 5) Seed privacy alert codes (optional; no-op if table missing) ==========
DO $$
BEGIN
  IF to_regclass('public.alert_codes') IS NOT NULL THEN
    INSERT INTO public.alert_codes(code, note) VALUES
      ('PRIVACY_RATE_LIMIT', 'Rate-limited over threshold'),
      ('PRIVACY_ERROR_RATE', 'Error rate above threshold'),
      ('PRIVACY_LAT_P95',   'p95 latency above threshold')
    ON CONFLICT (code) DO NOTHING;
  END IF;
END $$;

-- Notes:
-- - App code should insert into privacy_requests on each privacy endpoint completion.
-- - route_rate_limits can be used as append-only breadcrumbs to support forensic checks or SQL throttles.
-- - RLS read policies restrict visibility by org; writes are expected via service role or trusted backend.
