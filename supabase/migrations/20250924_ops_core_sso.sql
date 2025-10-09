-- 20250924_ops_core_sso.sql
-- Purpose: Core ops schema for rate limits, self-check metrics, SSO identities, admin views,
-- RPCs to log 429s and ensure org membership, and daily materialized views for fast dashboards.
-- Idempotent and safe to re-run.

-- Namespace
create schema if not exists ops;

-- 1) Rate limit events -----------------------------------------------------------
create table if not exists ops.rate_limit_events (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  route text not null,
  reason text not null,
  occurred_at timestamptz not null default now()
);

alter table ops.rate_limit_events enable row level security;
-- SELECT: admins only (adjust role check to your member table)
drop policy if exists rate_limit_read on ops.rate_limit_events;
create policy rate_limit_read on ops.rate_limit_events
for select to authenticated
using (
  exists (
    select 1 from public.organization_members m
    where m.org_id = ops.rate_limit_events.org_id
      and m.user_id = (select auth.uid())
      and m.role in ('admin','corp_admin')
  )
);
-- INSERT: service role only
drop policy if exists rate_limit_insert on ops.rate_limit_events;
create policy rate_limit_insert on ops.rate_limit_events
for insert to service_role
with check (true);

-- 2) Self-check metrics ----------------------------------------------------------
create table if not exists ops.selfcheck_metrics (
  id bigserial primary key,
  org_id uuid not null,
  check_name text not null,                   -- e.g., 'sso_selfcheck'
  ok boolean not null,
  code text null,
  ts timestamptz not null default now(),
  meta jsonb not null default '{}'::jsonb
);
create index if not exists idx_selfcheck_latest on ops.selfcheck_metrics(org_id, check_name, ts desc);

alter table ops.selfcheck_metrics enable row level security;
create policy if not exists selfcheck_read_org on ops.selfcheck_metrics
for select to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
-- inserts via service role only
create policy if not exists selfcheck_insert_service on ops.selfcheck_metrics
for insert to service_role
with check (true);

-- 3) SSO identities (admin view helper) -----------------------------------------
create table if not exists public.sso_identities (
  user_id uuid not null,
  provider text not null,                     -- 'azuread'|'okta'|'google'|...
  provider_id text not null,                  -- stable IdP subject or object ID
  last_login_at timestamptz null,
  primary key (user_id, provider)
);
alter table public.sso_identities enable row level security;
create policy if not exists sso_id_read_self on public.sso_identities
for select to authenticated
using (user_id = (select auth.uid()));

-- 4) SSO failure rate (24h) view for alerts -------------------------------------
create or replace view public.v_sso_failure_rate_24h as
with attempts as (
  select org_id,
         count(*) filter (where reason = 'failure')::int as failures_24h,
         count(*)::int as attempts_24h
  from (
    select org_id, 'attempt'::text as kind, occurred_at, null::text as reason
    from ops.rate_limit_events where route = '/sso/login' and occurred_at >= now() - interval '24 hours'
    union all
    select org_id, 'attempt', ts as occurred_at,
           case when ok then null else coalesce(code,'failure') end as reason
    from ops.selfcheck_metrics
    where check_name='sso_selfcheck' and ts >= now() - interval '24 hours'
  ) a
  group by org_id
)
select org_id,
       attempts_24h,
       failures_24h,
       case when attempts_24h > 0 then failures_24h::numeric/attempts_24h else 0 end as failure_rate_24h
from attempts;
grant select on public.v_sso_failure_rate_24h to authenticated;

-- 5) Admin SSO view (safe) ------------------------------------------------------
create or replace view public.v_sso_admin as
select u.id as user_id,
       u.email,
       (u.raw_app_meta_data->>'provider') as provider,
       i.provider_id,
       i.last_login_at
from auth.users u
left join public.sso_identities i on i.user_id = u.id;
grant select on public.v_sso_admin to authenticated;  -- narrow to admins via API layer if preferred

-- 6) Retention job (optional) ---------------------------------------------------
create or replace function ops.selfcheck_retention() returns void language plpgsql as $$
begin
  delete from ops.selfcheck_metrics where ts < now() - interval '90 days';
  delete from ops.rate_limit_events where occurred_at < now() - interval '90 days';
end $$;

-- RPCs (locked) -----------------------------------------------------------------
-- Log 429s
create or replace function public.log_429(p_route text, p_reason text default 'rate_limit')
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare v_org uuid := ((select auth.jwt()) ->> 'app_org_id')::uuid;
begin
  insert into ops.rate_limit_events(org_id, route, reason, occurred_at)
  values (v_org, p_route, p_reason, now());
end $$;
revoke all on function public.log_429(text,text) from public;
grant execute on function public.log_429(text,text) to service_role;

-- Ensure membership on first SSO login
create or replace function public.ensure_membership(p_org uuid)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
  insert into public.organization_members(org_id, user_id, role)
  values (p_org, (select auth.uid()), 'member')
  on conflict do nothing;
end $$;
revoke all on function public.ensure_membership(uuid) from public;
grant execute on function public.ensure_membership(uuid) to authenticated;

-- Supabase metrics/materialized views (optional fast dashboards) ----------------
-- Materialized view for daily org stats
create materialized view if not exists public.mv_daily_org_stats as
select date_trunc('day', ts)::date as day,
       org_id,
       count(*) filter (where check_name='sso_selfcheck') as selfchecks,
       count(*) filter (where check_name='sso_selfcheck' and ok=false) as selfcheck_failures,
       count(*) filter (where route='/sso/login') as sso_attempts
from (
  select org_id, check_name, ok, ts, null::text as route from ops.selfcheck_metrics
  union all
  select org_id, null::text as check_name, null::boolean as ok, occurred_at as ts, route from ops.rate_limit_events
) t
group by 1,2;

-- Unique index required for CONCURRENT refresh
create unique index if not exists ux_mv_daily_org_stats on public.mv_daily_org_stats(day, org_id);

-- Materialized view for daily truck stats (placeholder)
create materialized view if not exists public.mv_daily_truck_stats as
select date_trunc('day', ts)::date as day,
       org_id,
       count(*) as events
from ops.selfcheck_metrics
group by 1,2;
create unique index if not exists ux_mv_daily_truck_stats on public.mv_daily_truck_stats(day, org_id);

-- Read grants
grant select on public.mv_daily_org_stats, public.mv_daily_truck_stats to authenticated;

-- Quick smoke test helpers (the following queries are intended to be used manually):
-- A) MVs can refresh CONCURRENTLY (must have a UNIQUE index)
-- SELECT c.relname AS mv, i.relname AS unique_idx
-- FROM pg_class c
-- JOIN pg_index x ON x.indrelid = c.oid AND x.indisunique
-- JOIN pg_class i ON i.oid = x.indexrelid
-- WHERE c.relkind = 'm' AND c.relname IN ('mv_daily_truck_stats','mv_daily_org_stats');
-- B) RLS is ON for new tables
-- SELECT relname, relrowsecurity FROM pg_class WHERE relname IN ('sso_identities','selfcheck_metrics','rate_limit_events');
-- C) Views have intended grantees (read-only to authenticated, not public)
-- SELECT table_schema, table_name, grantee, privilege_type FROM information_schema.table_privileges
-- WHERE (table_schema, table_name) IN (("public","v_sso_admin"),("public","v_sso_failure_rate_24h"));
-- D) Definer functions + who can execute (no accidental PUBLIC grants)
-- SELECT n.nspname||'.'||p.proname AS fn, p.prosecdef AS is_definer,
--        array_agg(r.rolname ORDER BY r.rolname) FILTER (WHERE d.privilege_type='EXECUTE') AS grantees
-- FROM pg_proc p
-- JOIN pg_namespace n ON n.oid=p.pronamespace
-- LEFT JOIN information_schema.role_routine_grants d ON d.routine_schema=n.nspname AND d.routine_name=p.proname
-- LEFT JOIN pg_roles r ON r.rolname=d.grantee
-- WHERE n.nspname IN ('public','ops')
-- GROUP BY 1,2
-- ORDER BY 1;
