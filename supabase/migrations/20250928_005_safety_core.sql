-- 2025-09-xx_safety_core.sql
-- Hazards & alerts -----------------------------------------------------------
-- Note: a hazards table already exists (20250928_004_hazards.sql). We keep it.
-- This migration introduces driver-facing alert/ack telemetry and daily KPIs.

create table if not exists public.hazards (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  source text not null,
  type text not null,
  severity int not null check (severity between 1 and 5),
  lat double precision not null,
  lng double precision not null,
  radius_m int not null default 500,
  corridor_id text,
  expires_at timestamptz
);

-- Alert instances sent to drivers
create table if not exists public.driver_alerts (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  driver_id uuid not null,
  vehicle_id uuid,
  hazard_id uuid references public.hazards(id) on delete set null,
  org_id uuid not null,
  kind text not null,
  suggested_speed_kph int,
  distance_ahead_m int,
  ack_deadline_at timestamptz
);

-- Driver confirmations (ack + compliance window)
create table if not exists public.driver_acks (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  alert_id uuid references public.driver_alerts(id) on delete cascade,
  driver_id uuid not null,
  org_id uuid not null,
  acked boolean not null default true,
  latency_ms int not null,
  chosen_speed_kph int,
  guidance_followed boolean
);

-- Near-miss signals
create table if not exists public.near_misses (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  driver_id uuid not null,
  org_id uuid not null,
  alert_id uuid references public.driver_alerts(id),
  type text not null,
  value numeric,
  corridor_id text
);

-- Daily KPI spine per org & corridor
create table if not exists public.kpi_daily (
  day date not null,
  org_id uuid not null,
  corridor_id text,
  alerts int default 0,
  acks int default 0,
  ack_rate numeric,
  p50_ack_latency_ms int,
  p95_ack_latency_ms int,
  near_misses int default 0,
  speed_compliance_rate numeric,
  primary key (day, org_id, corridor_id)
);

-- Network benchmark (rolling medians by corridor)
create materialized view if not exists public.kpi_benchmark_corridor as
select
  day,
  corridor_id,
  percentile_cont(0.5) within group (order by coalesce(ack_rate,0)) as median_ack_rate,
  percentile_cont(0.5) within group (order by coalesce(p50_ack_latency_ms,0)) as median_p50_ack_ms,
  percentile_cont(0.5) within group (order by coalesce(p95_ack_latency_ms,0)) as median_p95_ack_ms
from public.kpi_daily
group by 1,2;

-- Helpful views --------------------------------------------------------------
-- Corridor cells as GeoJSON (for maplibre)
create or replace view public.v_risk_corridors_geo as
select
  id,
  org_id,
  alert_count,
  urgent_count,
  types,
  st_asgeojson(cell)::jsonb as geom
from public.risk_corridor_cells;

-- Insurer export: daily KPIs wide
create or replace view public.v_kpi_insurer_export as
select
  day,
  org_id,
  corridor_id,
  alerts,
  acks,
  coalesce(ack_rate,0) as ack_rate,
  coalesce(p50_ack_latency_ms,0) as p50_ack_latency_ms,
  coalesce(p95_ack_latency_ms,0) as p95_ack_latency_ms,
  near_misses,
  coalesce(speed_compliance_rate,0) as speed_compliance_rate
from public.kpi_daily;

-- RLS (multi-tenant) --------------------------------------------------------
alter table public.driver_alerts enable row level security;
alter table public.driver_acks   enable row level security;
alter table public.near_misses   enable row level security;
alter table public.kpi_daily     enable row level security;

-- Org isolation: org_id must match JWT custom claim app_org_id
create policy if not exists "driver_alerts org" on public.driver_alerts
  for select using (coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','') = org_id::text);

create policy if not exists "driver_acks org" on public.driver_acks
  for select using (coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','') = org_id::text);

create policy if not exists "near_misses org" on public.near_misses
  for select using (coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','') = org_id::text);

create policy if not exists "kpi_daily org" on public.kpi_daily
  for select using (coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','') = org_id::text);

-- Aggregation function (daily KPIs) -----------------------------------------
create or replace function public.refresh_kpi_daily(p_day date default current_date, p_org uuid default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Alerts per org/corridor
  insert into public.kpi_daily as k (day, org_id, corridor_id, alerts)
  select p_day, a.org_id, coalesce(h.corridor_id,'unknown') as corridor_id, count(*)::int
  from public.driver_alerts a
  left join public.hazards h on h.id = a.hazard_id
  where a.created_at >= p_day::timestamptz
    and a.created_at < (p_day + 1)::timestamptz
    and (p_org is null or a.org_id = p_org)
  group by a.org_id, coalesce(h.corridor_id,'unknown')
  on conflict (day, org_id, corridor_id) do update set alerts = excluded.alerts;

  -- Acks + latency percentiles + compliance
  with acks as (
    select
      da.org_id,
      coalesce(h.corridor_id,'unknown') as corridor_id,
      count(*)::int as acks,
      percentile_cont(0.5) within group (order by latency_ms) as p50_lat,
      percentile_cont(0.95) within group (order by latency_ms) as p95_lat,
      avg(case when guidance_followed then 1.0 else 0.0 end) as compliance
    from public.driver_acks ack
    join public.driver_alerts da on da.id = ack.alert_id
    left join public.hazards h on h.id = da.hazard_id
    where ack.created_at >= p_day::timestamptz
      and ack.created_at < (p_day + 1)::timestamptz
      and (p_org is null or da.org_id = p_org)
    group by da.org_id, coalesce(h.corridor_id,'unknown')
  )
  update public.kpi_daily k
  set acks = a.acks,
      ack_rate = case when alerts > 0 then a.acks::numeric/alerts else 0 end,
      p50_ack_latency_ms = a.p50_lat::int,
      p95_ack_latency_ms = a.p95_lat::int,
      speed_compliance_rate = a.compliance
  from acks a
  where k.day = p_day and k.org_id = a.org_id and k.corridor_id = a.corridor_id;

  -- Near misses
  with nm as (
    select org_id, coalesce(corridor_id,'unknown') as corridor_id, count(*)::int as ct
    from public.near_misses
    where created_at >= p_day::timestamptz
      and created_at < (p_day + 1)::timestamptz
      and (p_org is null or org_id = p_org)
    group by org_id, coalesce(corridor_id,'unknown')
  )
  update public.kpi_daily k
  set near_misses = nm.ct
  from nm
  where k.day = p_day and k.org_id = nm.org_id and k.corridor_id = nm.corridor_id;
end $$;

revoke all on function public.refresh_kpi_daily(date,uuid) from public;
grant execute on function public.refresh_kpi_daily(date,uuid) to service_role;
