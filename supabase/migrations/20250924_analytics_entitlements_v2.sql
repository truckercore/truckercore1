-- 20250924_analytics_entitlements_v2.sql
-- Entitlements/features, analytics usage/audit, resolver views, policy_smoke RPC, and retention helper
-- Safe to re-run (idempotent) and compatible with existing analytics entitlements migration.

-- 0) Safe re-runs
create extension if not exists pgcrypto;

-- 1) entitlements (augment existing table where needed)
create table if not exists public.entitlements (
  org_id uuid not null,
  feature text not null,
  region text not null default 'global',
  value jsonb not null default 'true'::jsonb,
  expires_at timestamptz null,
  created_at timestamptz not null default now(),
  created_by uuid null,
  primary key (org_id, feature, region)
);
-- If table already existed with different columns, add the missing ones (no destructive changes)
alter table if exists public.entitlements
  add column if not exists region text not null default 'global',
  add column if not exists value jsonb not null default 'true'::jsonb,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists created_by uuid;

create index if not exists entitlements_org_feat_region_idx on public.entitlements (org_id, feature, region);

alter table public.entitlements enable row level security;
create policy if not exists entitlements_read_org on public.entitlements
for select to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

-- 2) analytics_usage (per-call metering)
create table if not exists public.analytics_usage (
  id bigserial primary key,
  org_id uuid not null,
  region text not null,
  feature text not null,
  units int not null default 1,
  ok boolean not null,
  reason text not null check (reason in ('ok','entitlement_denied','k_anonymity_denied','plan_locked','role_locked')),
  at timestamptz not null default now()
);
create index if not exists analytics_usage_org_time_idx on public.analytics_usage (org_id, at desc);

alter table public.analytics_usage enable row level security;
create policy if not exists analytics_usage_read_org on public.analytics_usage
for select to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
revoke insert, update, delete on public.analytics_usage from authenticated, anon;

-- 3) analytics_audit (decisions + fingerprints)
create table if not exists public.analytics_audit (
  id bigserial primary key,
  org_id uuid not null,
  actor text not null,                       -- 'svc:edge' | 'user:{uuid}' | 'job:cron'
  action text not null,                      -- 'aggregate.query' | 'export.csv' | 'policy.check'
  region text not null,
  feature text not null,
  input_fingerprint text not null,           -- e.g., 'sha256:...'
  decision text not null check (decision in ('allow','deny')),
  reason text not null,                      -- 'ok' | 'entitlement_denied' | ...
  at timestamptz not null default now()
);
create index if not exists analytics_audit_org_time_idx on public.analytics_audit (org_id, at desc);

alter table public.analytics_audit enable row level security;
create policy if not exists analytics_audit_read_org on public.analytics_audit
for select to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
revoke insert, update, delete on public.analytics_audit from authenticated, anon;

-- 4) resolver helpers (views)

-- active-by-org (now)
create or replace view public.v_entitlement_now as
select
  e.org_id,
  e.feature,
  e.region,
  (e.value #>> '{}')::text as raw_value,
  coalesce((e.value ? 'limit')::bool, false) as has_limit,
  e.value ->> 'limit' as limit_value,
  e.expires_at,
  (e.expires_at is null or e.expires_at > now()) as active,
  e.created_at
from public.entitlements e;

-- flattened matrix (row per org/feature/region with active=true)
create or replace view public.v_entitlement_matrix as
select org_id, feature, region, active, expires_at
from public.v_entitlement_now
where active = true;

-- usage rollup 24h
create or replace view public.v_usage_24h as
select
  org_id,
  feature,
  region,
  sum(units) filter (where ok) as units_ok,
  sum(units) filter (where not ok) as units_denied,
  count(*) filter (where not ok) as calls_denied,
  max(at) as last_seen
from public.analytics_usage
where at >= now() - interval '24 hours'
group by 1,2,3
order by org_id, feature, region;

-- denial hotspots (7d)
create or replace view public.v_denial_hotspots as
select
  org_id,
  feature,
  region,
  count(*) filter (where not ok and reason='entitlement_denied') as denied_entitlement,
  count(*) filter (where not ok and reason='k_anonymity_denied') as denied_k,
  count(*) filter (where not ok) as denied_all,
  count(*) filter (where ok) as allowed_all,
  round(
    coalesce(count(*) filter (where not ok)::numeric / nullif(count(*),0), 0)
  ,4) as denial_rate,
  max(at) as last_denial_at
from public.analytics_usage
where at >= now() - interval '7 days'
group by 1,2,3
order by denial_rate desc nulls last;

-- 5) policy smoke RPC (service-role only): checks entitlement and preflight COUNT
create or replace function public.policy_smoke(
  p_org_id uuid,
  p_region text,
  p_feature text,
  p_table regclass,
  p_where text default null
) returns jsonb
language plpgsql
security definer
as $$
declare
  v_active boolean;
  v_expires timestamptz;
  v_sql text;
  v_count bigint := 0;
  v_decision text := 'deny';
  v_reason text := 'entitlement_denied';
begin
  select active, expires_at into v_active, v_expires
  from public.v_entitlement_now
  where org_id = p_org_id and feature = p_feature and (region = p_region or region = 'global')
  order by case when region='global' then 2 else 1 end
  limit 1;

  if v_active then
    v_decision := 'allow';
    v_reason := 'ok';
  end if;

  -- preflight COUNT when allowed
  if v_decision = 'allow' then
    v_sql := 'select count(*) from ' || p_table::text;
    if p_where is not null and length(p_where) > 0 then
      v_sql := v_sql || ' where ' || p_where;
    end if;
    execute v_sql into v_count;
  end if;

  -- usage + audit
  insert into public.analytics_usage (org_id, region, feature, units, ok, reason)
  values (p_org_id, p_region, p_feature, 1, (v_decision='allow'), v_reason);

  insert into public.analytics_audit (org_id, actor, action, region, feature, input_fingerprint, decision, reason)
  values (p_org_id, 'svc:policy_smoke', 'policy.check', p_region, p_feature, 'sha256:' || encode(digest(coalesce(p_where,''),'sha256'),'hex'), v_decision, v_reason);

  return jsonb_build_object(
    'decision', v_decision,
    'reason', v_reason,
    'expires_at', v_expires,
    'preflight_count', v_count
  );
end $$;

revoke all on function public.policy_smoke(uuid,text,text,regclass,text) from public, anon, authenticated;
grant execute on function public.policy_smoke(uuid,text,text,regclass,text) to service_role;

-- 6) retention helper (90d default; service-only)
create or replace function public.prune_analytics(days int default 90)
returns void language plpgsql security definer as $$
begin
  delete from public.analytics_usage where at < now() - make_interval(days=>days);
  delete from public.analytics_audit where at < now() - make_interval(days=>days);
end $$;
revoke all on function public.prune_analytics(int) from public, anon, authenticated;
grant execute on function public.prune_analytics(int) to service_role;

-- 7) Grants for views (client-readable)
grant select on public.v_entitlement_now, public.v_entitlement_matrix, public.v_usage_24h, public.v_denial_hotspots to authenticated, anon;
