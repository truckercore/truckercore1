-- 001_slowdown_alerts.sql
-- Enums
do $$
begin
  if not exists (select 1 from pg_type t join pg_namespace n on n.oid=t.typnamespace where n.nspname='public' and t.typname='alert_type') then
    create type public.alert_type as enum ('SLOWDOWN', 'INCIDENT', 'WEATHER');
  end if;
end$$;

-- Tables
create table if not exists public.safety_alerts (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  driver_id uuid not null,
  vehicle_id uuid,
  alert_type public.alert_type not null default 'SLOWDOWN',
  severity int not null check (severity between 1 and 5),
  message text not null,
  lat double precision not null,
  lng double precision not null,
  road_name text,
  source text not null default 'here', -- 'here' | 'mapbox' | 'crowd'
  ahead_distance_m int,
  speed_ahead_kph int,
  driver_speed_kph int,
  eta_delta_sec int,
  hos_fatigue_flag boolean default false,
  segment_key text,
  fired_at timestamptz not null default now()
);

create index if not exists idx_safety_alerts_org_time on public.safety_alerts (org_id, fired_at desc);
create index if not exists idx_safety_alerts_driver_time on public.safety_alerts (driver_id, fired_at desc);
create index if not exists idx_safety_alerts_segment_time on public.safety_alerts (segment_key, fired_at desc);

-- Optional raw detections for tuning thresholds
create table if not exists public.slowdown_events (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  driver_id uuid not null,
  lat double precision not null,
  lng double precision not null,
  heading double precision,
  driver_speed_kph int,
  speed_ahead_kph int,
  distance_probe_m int,
  delta_kph int,
  detected_at timestamptz not null default now()
);

create index if not exists idx_slowdown_events_org_time on public.slowdown_events (org_id, detected_at desc);

-- RLS
alter table public.safety_alerts enable row level security;
alter table public.slowdown_events enable row level security;

-- Policies (tenant scoped by org_id via JWT claim app_org_id)
drop policy if exists "alerts tenant read" on public.safety_alerts;
create policy "alerts tenant read" on public.safety_alerts
for select to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

drop policy if exists "alerts tenant insert" on public.safety_alerts;
create policy "alerts tenant insert" on public.safety_alerts
for insert to authenticated
with check (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

drop policy if exists "events tenant read" on public.slowdown_events;
create policy "events tenant read" on public.slowdown_events
for select to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

drop policy if exists "events tenant insert" on public.slowdown_events;
create policy "events tenant insert" on public.slowdown_events
for insert to authenticated
with check (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

-- Optional: service role insert bypass for Edge Functions
drop policy if exists safety_alerts_service_insert on public.safety_alerts;
create policy safety_alerts_service_insert
on public.safety_alerts for insert to service_role
with check (true);

drop policy if exists slowdown_events_service_insert on public.slowdown_events;
create policy slowdown_events_service_insert
on public.slowdown_events for insert to service_role
with check (true);

-- Hints:
-- • Enable Realtime on public.safety_alerts in Supabase if you want push updates.
-- • Ensure JWTs carry app_org_id and sub (driver id) claims.
