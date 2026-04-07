-- 20250924_analytics_entitlements.sql
-- Purpose: Entitlements, k-anonymity policies, analytics usage and audit logs,
--          rollup views, and guarded RPCs for preflight counting and k-anonymous
--          aggregation. Idempotent and safe to re-run.

-- ========== Core tables ==========

create table if not exists public.entitlements (
  org_id uuid not null,
  feature text not null,
  region text not null,
  expires_at timestamptz null,
  meta jsonb not null default '{}'::jsonb,
  primary key (org_id, feature, region)
);

alter table public.entitlements enable row level security;
create policy if not exists entitlements_read_org on public.entitlements
for select to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

create table if not exists public.k_anon_policies (
  feature text not null,
  region text not null,
  k int not null default 10,
  primary key (feature, region)
);

alter table public.k_anon_policies enable row level security;
create policy if not exists k_anon_policies_read_all on public.k_anon_policies
for select to authenticated using (true);

-- Usage and audit logs
create table if not exists public.analytics_usage (
  id bigserial primary key,
  org_id uuid not null,
  region text not null,
  feature text not null,
  units int not null check (units >= 0),
  ok boolean not null,
  reason text not null check (reason in ('ok','entitlement_denied','k_anonymity','invalid_region','malformed_request')),
  at timestamptz not null default now()
);
create index if not exists analytics_usage_org_time_idx on public.analytics_usage (org_id, at desc);

alter table public.analytics_usage enable row level security;
create policy if not exists analytics_usage_read_org on public.analytics_usage
for select to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

create table if not exists public.analytics_audit (
  id bigserial primary key,
  org_id uuid not null,
  actor text,
  action text not null check (action in ('aggregate.query','aggregate.export','risk.score','risk.export','entitlement.refresh')),
  region text not null,
  feature text not null,
  input_fingerprint text,
  decision text not null check (decision in ('allow','deny')),
  reason text,
  at timestamptz not null default now()
);
create index if not exists analytics_audit_org_time_idx on public.analytics_audit (org_id, at desc);

alter table public.analytics_audit enable row level security;
create policy if not exists analytics_audit_read_org on public.analytics_audit
for select to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

-- ========== Views ==========

-- Entitlement snapshots
create or replace view public.v_entitlement_now as
select e.*,
       (e.expires_at is null or e.expires_at > now()) as active
from public.entitlements e;

create or replace view public.v_entitlement_matrix as
select org_id, feature, region, active
from public.v_entitlement_now;

-- Usage rollups
create or replace view public.v_usage_24h as
select org_id, region, feature,
       sum(units) as units,
       sum((ok::int)) as calls_ok,
       sum((not ok)::int) as calls_denied,
       max(at) as last_call
from public.analytics_usage
where at >= now() - interval '24 hours'
group by org_id, region, feature;

create or replace view public.v_usage_30d as
select org_id, region, feature,
       sum(units) as units_30d,
       sum((ok::int))  as ok_calls_30d,
       sum((not ok)::int) as denied_calls_30d,
       max(at) as last_call
from public.analytics_usage
where at >= now() - interval '30 days'
group by org_id, region, feature;

-- Denial hotspots and policy mix
create or replace view public.v_denial_hotspots as
select org_id, feature, region,
       sum((reason='entitlement_denied')::int) as denied_entitlement,
       sum((reason='k_anonymity')::int)        as denied_k,
       sum((reason='invalid_region')::int)     as denied_region,
       sum((reason='malformed_request')::int)  as denied_malformed,
       count(*)                                as total_attempts,
       max(at)                                 as last_attempt
from public.analytics_usage
where at >= now() - interval '7 days'
group by org_id, feature, region
order by denied_entitlement desc, denied_k desc, denied_region desc;

create or replace view public.v_policy_denial_mix as
select reason, count(*) as n
from public.analytics_usage
where not ok and at >= now() - interval '14 days'
group by reason
order by n desc;

-- Coverage
create or replace view public.v_entitlement_coverage as
select org_id,
       count(*) filter (where active) as features_active,
       jsonb_object_agg(feature, active) filter (where true) as features
from public.v_entitlement_now
group by org_id;

-- ========== RPCs (server-only execution) ==========

-- Preflight count (guarded). Returns a simple count based on args contract.
create or replace function public.exec_count_guard(q text, args jsonb)
returns table(count bigint)
language plpgsql
security definer
as $$
begin
  -- Implement per-query-family safe count; example based on args contract
  return query
  select count(*)
  from public.market_events
  where org_id = (args->>'org_id')::uuid
    and region  = (args->>'region')
    and ts >= (args->>'from')::timestamptz
    and ts <  (args->>'to')::timestamptz;
end $$;

revoke all on function public.exec_count_guard(text,jsonb) from public, anon, authenticated;
grant execute on function public.exec_count_guard(text,jsonb) to service_role;

-- Guarded aggregate (k-anonymity enforced)
create or replace function public.market_aggregate_rpc(
  p_org uuid, p_region text, p_min_k int, p_from timestamptz, p_to timestamptz
) returns table(lane text, shipments int, revenue_usd numeric)
language plpgsql
security definer
stable
as $$
begin
  return query
  with base as (
    select lane, revenue_usd
    from public.market_events
    where org_id = p_org
      and region = p_region
      and ts >= p_from and ts < p_to
  ),
  buckets as (
    select lane, count(*) as shipments, sum(revenue_usd) as revenue_usd
    from base group by lane
  )
  select lane, shipments, revenue_usd
  from buckets
  where shipments >= p_min_k
  order by revenue_usd desc
  limit 500;
end $$;

revoke all on function public.market_aggregate_rpc(uuid,text,int,timestamptz,timestamptz) from public, anon, authenticated;
grant execute on function public.market_aggregate_rpc(uuid,text,int,timestamptz,timestamptz) to service_role;

-- ========== Notes ==========
-- Views are readable to authenticated by default via schema privileges and RLS read on base tables.
-- CI guard example (deny spikes):
-- select * from public.v_denial_hotspots where denied_entitlement > 0 or denied_k > 5;
