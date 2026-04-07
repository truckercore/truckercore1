-- =============================================================
-- Usage Events + Monthly Rollups + Reconciliation (idempotent)
-- =============================================================

-- 0) Helpers (compat with existing helpers; safe to re-create)
create or replace function public.app_org() returns uuid
language sql stable as $$ select nullif(auth.jwt()->>'app_org_id','')::uuid $$;

create or replace function public.app_role() returns text
language sql stable as $$ select coalesce(auth.jwt()->>'app_role','') $$;

create or replace function public.is_roaddogg() returns boolean
language sql stable as $$ select (auth.jwt()->>'svc')='roaddogg' or public.app_role()='roaddogg_service' $$;

-- 1) Raw usage events
create table if not exists public.usage_events (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  user_id uuid null,
  feature_key text not null,                 -- e.g., 'ai.capacity.prediction'
  units int not null default 1,              -- billable units
  request_id text null,                      -- traceability
  stripe_meter_item_id text null,            -- optional (for metered billing)
  at timestamptz not null default now(),
  meta jsonb null
);

-- Useful indexes
create index if not exists idx_usage_org_time on public.usage_events(org_id, at desc);
create index if not exists idx_usage_feature_time on public.usage_events(feature_key, at desc);

-- RLS
alter table public.usage_events enable row level security;

-- Read: authenticated within same org
do $$ begin
  create policy usage_ro on public.usage_events
    for select to authenticated using (public.app_org() = org_id);
exception when duplicate_object then null; end $$;

-- Write: Roaddogg/service producers only (via authenticated token carrying svc/role hint). Adjust as needed if writing via service role.
do $$ begin
  create policy usage_roaddogg_w on public.usage_events
    for insert to authenticated
    with check (public.is_roaddogg());
exception when duplicate_object then null; end $$;

-- 2) Monthly rollup (UTC)
create materialized view if not exists public.usage_monthly as
select
  org_id,
  feature_key,
  date_trunc('month', at) as period,
  sum(units) as total_units,
  count(distinct user_id) as distinct_users
from public.usage_events
group by 1,2,3;

-- Unique index required for CONCURRENTLY refresh
create unique index if not exists ux_usage_monthly
  on public.usage_monthly(org_id, feature_key, period);

-- 3) Report function (stable)
create or replace function public.usage_report(
  p_org uuid,
  p_start date,
  p_end date
) returns table(
  feature_key text,
  period date,
  total_units bigint,
  distinct_users bigint
) language sql stable as $$
  select feature_key,
         period::date,
         total_units,
         distinct_users
  from public.usage_monthly
  where org_id = p_org
    and period >= date_trunc('month', p_start)
    and period <  (date_trunc('month', p_end) + interval '1 month')
  order by feature_key, period;
$$;

-- 4) Stripe reconciliation (optional)
create table if not exists public.stripe_usage_sync (
  id bigserial primary key,
  org_id uuid not null,
  feature_key text not null,
  period_start date not null,
  quantity bigint not null,
  stripe_event_id text null,
  synced_at timestamptz default now(),
  unique (org_id, feature_key, period_start)
);

-- 5) Drift and KPIs
create or replace view public.v_usage_sync_drift as
select
  m.org_id, m.feature_key, m.period::date as period_start,
  m.total_units as internal_units,
  coalesce(s.quantity,0) as synced_units,
  (m.total_units - coalesce(s.quantity,0)) as delta
from public.usage_monthly m
left join public.stripe_usage_sync s
  on s.org_id = m.org_id
 and s.feature_key = m.feature_key
 and s.period_start = m.period::date
where abs(m.total_units - coalesce(s.quantity,0)) > 0;

create or replace view public.v_usage_kpis as
select
  (select sum(total_units) from public.usage_monthly where period >= date_trunc('month', now())) as units_mtd,
  (select count(distinct org_id) from public.usage_monthly where period >= date_trunc('month', now())) as active_orgs_mtd,
  (select count(*) from public.v_usage_sync_drift) as sync_drift_open;
