-- 20250923_map_layers.sql
-- Purpose: Core map layers schema (weigh stations, truck stops), live status tables,
--          crowd reports with RLS, and latest views for Flutter overlays.
-- Safe to re-run; uses IF NOT EXISTS and CREATE OR REPLACE.

-- Enable PostGIS if available (harmless if already enabled). If extension is not
-- available on the target Postgres, this will be ignored by Supabase hosting.
create extension if not exists postgis;

-- ========== CORE STATIC LAYERS ==========
create table if not exists public.weigh_stations (
  id uuid primary key default gen_random_uuid(),
  ext_id text,
  name text not null,
  state text check (char_length(state) = 2),
  location geography(Point, 4326) not null,
  direction text,
  facilities jsonb,
  created_at timestamptz not null default now()
);
create index if not exists weigh_stations_gix on public.weigh_stations using gist (location);
create unique index if not exists weigh_stations_ext_unique on public.weigh_stations (ext_id) where ext_id is not null;

create table if not exists public.truck_stops (
  id uuid primary key default gen_random_uuid(),
  ext_id text,
  name text not null,
  brand text,
  location geography(Point, 4326) not null,
  amenities jsonb,
  created_at timestamptz not null default now()
);
create index if not exists truck_stops_gix on public.truck_stops using gist (location);
create unique index if not exists truck_stops_ext_unique on public.truck_stops (ext_id) where ext_id is not null;

-- ========== LIVE LAYERS ==========
create table if not exists public.weigh_station_status (
  station_id uuid references public.weigh_stations(id) on delete cascade,
  status text check (status in ('open','closed','bypass','unknown')) not null,
  source text not null,
  observed_at timestamptz not null,
  meta jsonb,
  primary key (station_id, observed_at, source)
);
create index if not exists weigh_status_station_time_idx on public.weigh_station_status (station_id, observed_at desc);

create table if not exists public.parking_status (
  stop_id uuid references public.truck_stops(id) on delete cascade,
  occupancy_pct numeric check (occupancy_pct between 0 and 100),
  spots_total int,
  source text not null,
  observed_at timestamptz not null,
  meta jsonb,
  primary key (stop_id, observed_at, source)
);
create index if not exists parking_status_stop_time_idx on public.parking_status (stop_id, observed_at desc);

create table if not exists public.fuel_prices (
  stop_id uuid references public.truck_stops(id) on delete cascade,
  diesel_price_usd numeric(6,3),
  discount_usd numeric(6,3),
  source text not null,
  observed_at timestamptz not null,
  meta jsonb,
  primary key (stop_id, observed_at, source)
);
create index if not exists fuel_prices_stop_time_idx on public.fuel_prices (stop_id, observed_at desc);

create table if not exists public.traffic_incidents (
  id uuid primary key default gen_random_uuid(),
  ext_id text,
  title text,
  description text,
  severity int,
  start_at timestamptz,
  end_at timestamptz,
  bounds geography(Polygon, 4326),
  center geography(Point, 4326),
  source text not null,
  observed_at timestamptz not null
);
create index if not exists traffic_incidents_center_gix on public.traffic_incidents using gist (center);
create index if not exists traffic_incidents_time_idx on public.traffic_incidents (observed_at desc);

-- ========== CROWDSOURCING ==========
create table if not exists public.crowd_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid,
  org_id uuid,
  kind text check (kind in ('parking','weigh_station')) not null,
  stop_id uuid,
  station_id uuid,
  value text not null,
  observed_at timestamptz not null default now(),
  location geography(Point, 4326),
  meta jsonb
);
create index if not exists crowd_reports_when_idx on public.crowd_reports (observed_at desc);
create index if not exists crowd_reports_loc_gix on public.crowd_reports using gist (location);

-- ========== VIEWS FOR MAPS ==========
create or replace view public.v_weigh_station_latest as
select w.id, w.name, w.state,
       st_asgeojson(w.location)::jsonb as geo,
       (select status from public.weigh_station_status s
         where s.station_id = w.id order by observed_at desc limit 1) as status,
       (select observed_at from public.weigh_station_status s
         where s.station_id = w.id order by observed_at desc limit 1) as status_at
from public.weigh_stations w;

create or replace view public.v_parking_latest as
select t.id, t.name, t.brand,
       st_asgeojson(t.location)::jsonb as geo,
       (select occupancy_pct from public.parking_status p
         where p.stop_id = t.id order by observed_at desc limit 1) as occupancy_pct,
       (select observed_at from public.parking_status p
         where p.stop_id = t.id order by observed_at desc limit 1) as observed_at
from public.truck_stops t;

create or replace view public.v_fuel_latest as
select t.id, t.name, t.brand,
       st_asgeojson(t.location)::jsonb as geo,
       (select diesel_price_usd from public.fuel_prices f
         where f.stop_id = t.id order by observed_at desc limit 1) as diesel_price_usd,
       (select observed_at from public.fuel_prices f
         where f.stop_id = t.id order by observed_at desc limit 1) as observed_at
from public.truck_stops t;

-- ========== RLS / GRANTS ==========
-- Public read (map layers)
revoke all on public.v_weigh_station_latest    from public;
revoke all on public.v_parking_latest          from public;
revoke all on public.v_fuel_latest             from public;
revoke all on public.weigh_stations            from public;
revoke all on public.truck_stops               from public;
revoke all on public.traffic_incidents         from public;

grant select on public.v_weigh_station_latest, public.v_parking_latest, public.v_fuel_latest,
              public.weigh_stations, public.truck_stops, public.traffic_incidents
  to anon, authenticated;

-- Crowd reports: tenant-scoped
alter table public.crowd_reports enable row level security;

create policy if not exists crowd_read on public.crowd_reports
for select to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

create policy if not exists crowd_write on public.crowd_reports
for insert to authenticated
with check (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
