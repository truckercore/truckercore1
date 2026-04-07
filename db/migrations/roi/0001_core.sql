begin;

create type ai_roi_type as enum ('promo_uplift','fuel_savings','hos_violation_avoidance');

create table if not exists ai_roi_events (
  id bigserial primary key,
  org_id uuid not null,
  driver_id uuid,
  load_id uuid,
  event_type ai_roi_type not null,
  amount_cents int not null,                    -- positive dollars saved or uplift
  rationale jsonb not null default '{}'::jsonb, -- inputs/assumptions for attribution
  model_key text,                               -- which model/version made suggestion
  model_version text,
  created_at timestamptz not null default now()
);
create index if not exists idx_ai_roi_events_org_time on ai_roi_events(org_id, created_at desc);
create index if not exists idx_ai_roi_events_type on ai_roi_events(event_type);

-- Optional baselines for attribution (fuel price, baseline violation rate, promo ctr, etc.)
create table if not exists ai_roi_baselines (
  org_id uuid not null,
  key text not null,           -- e.g., 'fuel_price_usd_per_gal', 'hos_violation_rate'
  value numeric not null,
  effective_at timestamptz not null default now(),
  primary key(org_id, key, effective_at)
);

-- Canonical rollups (materialized view + refresh function)
create materialized view if not exists ai_roi_rollup_day as
select
  org_id,
  date_trunc('day', created_at) as day,
  sum(amount_cents) filter (where event_type='fuel_savings')            as fuel_cents,
  sum(amount_cents) filter (where event_type='hos_violation_avoidance') as hos_cents,
  sum(amount_cents) filter (where event_type='promo_uplift')            as promo_cents,
  sum(amount_cents)                                                   as total_cents
from ai_roi_events
group by 1,2;

create or replace function ai_roi_rollup_refresh()
returns void language sql as $$
  refresh materialized view concurrently ai_roi_rollup_day;
$$;

-- Minimal RLS (service writes, org-scoped reads)
alter table ai_roi_events enable row level security;
drop policy if exists roi_ro_org on ai_roi_events;
create policy roi_ro_org on ai_roi_events for select to authenticated using (
  (current_setting('request.jwt.claims', true)::jsonb->>'app_org_id')::uuid = org_id
);
drop policy if exists roi_service on ai_roi_events;
create policy roi_service on ai_roi_events for all to service_role using (true) with check (true);

grant select on ai_roi_rollup_day to authenticated, anon;

commit;
