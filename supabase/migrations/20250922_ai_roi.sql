-- ROI event table and rollups (safe-to-rerun)

-- Base table
create table if not exists public.ai_roi_events (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  driver_user_id uuid null,
  event_type text not null check (event_type in ('promo_redeemed','fuel_saved','hos_violation_avoided')),
  amount_usd numeric(12,2) not null check (amount_usd >= 0),  -- normalized to USD
  baseline jsonb not null default '{}'::jsonb,                -- e.g., {"fuel_price_usd_per_gal":3.90,"baseline_violation_rate":0.08}
  metadata jsonb not null default '{}'::jsonb,                -- e.g., promo_id, gallons_saved, lane_id
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);
create index if not exists idx_ai_roi_events_org_time on public.ai_roi_events (org_id, occurred_at desc);

-- RLS: enable + org-scoped read for authenticated users
alter table public.ai_roi_events enable row level security;
create policy if not exists ai_roi_events_read_org on public.ai_roi_events
for select to authenticated
using (
  org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','')
);
-- Inserts should be via service role only; no public insert policy

-- Daily rollup view by org and type
create or replace view public.v_ai_roi_daily as
select
  org_id,
  date_trunc('day', occurred_at)::date as day,
  event_type,
  sum(amount_usd)::numeric(14,2) as total_usd,
  count(*) as events
from public.ai_roi_events
group by 1,2,3;

-- Weekly materialized view by org (refreshable)
create materialized view if not exists public.ai_roi_weekly as
select
  org_id,
  date_trunc('week', occurred_at)::date as week_start,
  sum(case when event_type='fuel_saved' then amount_usd else 0 end)::numeric(14,2) as fuel_saved_usd,
  sum(case when event_type='promo_redeemed' then amount_usd else 0 end)::numeric(14,2) as promo_uplift_usd,
  sum(case when event_type='hos_violation_avoided' then amount_usd else 0 end)::numeric(14,2) as hos_avoid_usd,
  count(*) as events
from public.ai_roi_events
group by 1,2
with no data;

create index if not exists idx_ai_roi_weekly_org_week on public.ai_roi_weekly (org_id, week_start);

-- Helper to refresh MV (security definer for service role)
create or replace function public.fn_ai_roi_refresh_weekly()
returns void
language sql
security definer
as $$
  refresh materialized view concurrently public.ai_roi_weekly;
$$;

revoke all on function public.fn_ai_roi_refresh_weekly() from public;
grant execute on function public.fn_ai_roi_refresh_weekly() to service_role;

-- Exec-facing unified view (latest 30 days)
create or replace view public.v_ai_roi_exec_30d as
with window as (
  select * from public.ai_roi_events where occurred_at >= now() - interval '30 days'
)
select
  org_id,
  sum(case when event_type='fuel_saved' then amount_usd else 0 end)::numeric(14,2) as fuel_saved_30d_usd,
  sum(case when event_type='promo_redeemed' then amount_usd else 0 end)::numeric(14,2) as promo_uplift_30d_usd,
  sum(case when event_type='hos_violation_avoided' then amount_usd else 0 end)::numeric(14,2) as hos_avoid_30d_usd,
  count(*) as events_30d
from window
group by org_id;
