-- Optional PostGIS & Geofencing migration for TruckerCore
-- Run AFTER applying docs/supabase/fleet_dispatch_schema.sql

-- 0) Enable PostGIS
create extension if not exists postgis;

-- 1) Geofence tables (simple polygons and points of interest)
create table if not exists public.geofences (
  id uuid primary key default gen_random_uuid(),
  carrier_id uuid not null,
  name text not null,
  area geography(Polygon,4326) not null,
  kind text default 'custom',
  created_at timestamptz not null default now()
);

create index if not exists idx_geofences_carrier on public.geofences(carrier_id);
create index if not exists idx_geofences_area on public.geofences using gist (area);

alter table public.geofences enable row level security;
drop policy if exists geofences_tenant_select on public.geofences;
create policy geofences_tenant_select on public.geofences
  for select using ((auth.jwt() ->> 'org_id')::uuid = carrier_id);
drop policy if exists geofences_tenant_insert on public.geofences;
create policy geofences_tenant_insert on public.geofences
  for insert with check ((auth.jwt() ->> 'org_id')::uuid = carrier_id);
drop policy if exists geofences_tenant_update on public.geofences;
create policy geofences_tenant_update on public.geofences
  for update using ((auth.jwt() ->> 'org_id')::uuid = carrier_id);

-- 2) Convenience views to project lat/lng into geography points without changing base tables
create or replace view public.v_truck_positions_geo as
select
  p.id,
  p.truck_id,
  ST_SetSRID(ST_MakePoint(p.lng, p.lat),4326)::geography as position,
  p.lat,
  p.lng,
  p.speed_kph,
  p.heading_deg,
  p.odometer_km,
  p.gps_ts,
  p.source,
  p.created_at
from public.truck_positions p;

create or replace view public.v_truck_current_positions_geo as
select
  cp.truck_id,
  ST_SetSRID(ST_MakePoint(cp.lng, cp.lat),4326)::geography as position,
  cp.lat,
  cp.lng,
  cp.speed_kph,
  cp.heading_deg,
  cp.odometer_km,
  cp.gps_ts,
  cp.updated_at
from public.truck_current_positions cp;

-- 3) Example helper: trucks currently inside any geofence of same carrier
create or replace view public.v_trucks_in_geofences as
select
  t.id as truck_id,
  g.id as geofence_id,
  g.name as geofence_name,
  cp.lat,
  cp.lng,
  cp.gps_ts
from public.trucks t
join public.truck_current_positions cp on cp.truck_id = t.id
join public.geofences g on g.carrier_id = t.carrier_id
where ST_Contains(g.area::geometry, ST_SetSRID(ST_MakePoint(cp.lng, cp.lat),4326)::geometry);

-- RLS for the views is inherited from underlying tables.
