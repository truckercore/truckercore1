-- 002_hazards_extensions.sql
-- Enable required extensions for earth distance calculations/indexing
create extension if not exists cube;
create extension if not exists earthdistance;

-- Extend alert_type enum with additional kinds if the enum exists
do $$
begin
  if exists (select 1 from pg_type t join pg_namespace n on n.oid=t.typnamespace where n.nspname='public' and t.typname='alert_type') then
    begin
      alter type public.alert_type add value if not exists 'WORKZONE';
      alter type public.alert_type add value if not exists 'WEATHER';
      alter type public.alert_type add value if not exists 'SPEED';
      alter type public.alert_type add value if not exists 'OFFROUTE';
      alter type public.alert_type add value if not exists 'WEIGH';
      alter type public.alert_type add value if not exists 'FATIGUE';
    exception when duplicate_object then null; -- ignore race
    end;
  end if;
end$$;

-- Optional reference data for weigh/inspection stations
create table if not exists public.weigh_stations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  lat double precision not null,
  lng double precision not null,
  direction text, -- NB/SB/EB/WB/Both
  highway text,
  state text,
  is_open boolean, -- nullable if unknown
  updated_at timestamptz default now()
);
-- Geospatial index using earthdistance (requires cube + earthdistance)
create index if not exists weigh_stations_geo_idx on public.weigh_stations using gist (ll_to_earth(lat, lng));

-- Minimal HOS sessions table (if not present)
create table if not exists public.hos_sessions (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null,
  org_id uuid not null,
  on_duty_sec int default 0,
  driving_sec int default 0,
  last_reset_at timestamptz,
  updated_at timestamptz default now()
);

-- Handy view for recent alerts per driver
create or replace view public.v_recent_alerts as
select driver_id,
       max(fired_at) as last_alert_at,
       count(*) filter (where fired_at > now() - interval '1 hour') as last_hour
from public.safety_alerts
group by driver_id;

-- Nearby weigh stations RPC
create or replace function public.nearby_weigh_stations(lat_in double precision, lng_in double precision, radius_m int)
returns setof public.weigh_stations
language sql
stable
as $$
select *
from public.weigh_stations
where earth_distance(ll_to_earth(lat_in, lng_in), ll_to_earth(lat, lng)) <= radius_m
order by earth_distance(ll_to_earth(lat_in, lng_in), ll_to_earth(lat, lng)) asc
$$;
