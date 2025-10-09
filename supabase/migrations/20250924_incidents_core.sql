-- 20250924_incidents_core.sql
-- Purpose: Dedup & retention for traffic incidents, normalization map, bbox RPC, and helpful indexes.
-- All statements are idempotent and safe to re-run.

-- Ensure PostGIS extension for geometry support
create extension if not exists postgis;

-- Core incidents table (lean, ingestion-friendly)
create table if not exists public.traffic_incidents (
  id uuid primary key default gen_random_uuid(),
  ext_id text null,
  source text not null,
  title text null,
  description text null,
  start_at timestamptz null,
  end_at timestamptz null,
  observed_at timestamptz not null default now(),
  -- Store minimal geometry. Prefer center point; bounds may be polygon/line.
  center geometry(Point, 4326) null,
  bounds geometry(Geometry, 4326) null,
  severity int null check (severity between 1 and 4),
  meta jsonb not null default '{}'::jsonb
);

-- Helpful geometry index (optional; skip if GIST not supported)
do $$ begin
  perform 1 from pg_indexes where schemaname='public' and indexname='traffic_incidents_geom_gix';
  if not found then
    execute 'create index traffic_incidents_geom_gix on public.traffic_incidents using gist (coalesce(center, bounds))';
  end if;
end $$;

-- Unique external identity per source + start time (dedup across re-ingests)
create unique index if not exists traffic_incidents_ext_uniq
on public.traffic_incidents (ext_id, source, start_at)
where ext_id is not null and start_at is not null;

-- Retention GC (keep N days, default 30)
create or replace function public.prune_incidents(days int default 30)
returns void
language plpgsql
as $$
begin
  delete from public.traffic_incidents
  where coalesce(end_at, observed_at) < now() - make_interval(days => days);
end $$;

-- Severity & category normalization map
create table if not exists public.incident_type_map (
  source text not null,
  raw_category text not null,
  normalized text not null,  -- 'closure','restriction','weather','accident','other'
  severity int not null check (severity between 1 and 4),
  primary key (source, raw_category)
);

-- Overlay view with normalized kind/severity and compact GeoJSON geometry
create or replace view public.v_incidents_overlay as
select
  i.id, i.source, i.ext_id,
  coalesce(m.normalized, 'other') as kind,
  coalesce(m.severity, i.severity) as severity,
  i.title, i.description, i.start_at, i.end_at,
  st_asgeojson(coalesce(i.center, st_centroid(i.bounds)))::jsonb as geo
from public.traffic_incidents i
left join public.incident_type_map m
  on m.source = i.source
 and m.raw_category = (i.meta->>'category');

-- Pre-fill common DOT 511 and NOAA categories (examples)
insert into public.incident_type_map (source, raw_category, normalized, severity) values
('dot511','Road Closed','closure',4),
('dot511','Lane Closure','restriction',2),
('dot511','Construction','restriction',2),
('dot511','Crash','accident',3),
('dot511','Jackknifed Tractor Trailer','accident',4),
('dot511','Disabled Vehicle','accident',2),
('dot511','Congestion','restriction',1),
('dot511','Hazardous Materials','restriction',3),
('noaa','Tornado Warning','weather',4),
('noaa','Severe Thunderstorm Warning','weather',3),
('noaa','Winter Storm Warning','weather',3),
('noaa','Blizzard Warning','weather',4),
('noaa','Flood Warning','weather',3),
('noaa','Flash Flood Warning','weather',4),
('noaa','Dense Fog Advisory','weather',2),
('noaa','High Wind Warning','weather',3)
on conflict do nothing;

-- BBox RPC optimized for mobile (thin payloads)
create or replace function public.incidents_in_bbox(bbox geometry, max_rows int default 500)
returns table(
  id uuid, source text, kind text, severity int,
  start_at timestamptz, end_at timestamptz, geo jsonb
)
language sql stable
as $$
  select v.id, v.source, v.kind, v.severity, v.start_at, v.end_at, v.geo
  from public.v_incidents_overlay v
  where st_intersects(
          st_setsrid(st_geomfromgeojson(v.geo::text),4326),
          bbox
        )
    and v.start_at >= now() - interval '7 days'
  order by coalesce(v.end_at, v.start_at) desc
  limit max_rows
$$;

grant execute on function public.incidents_in_bbox(geometry,int) to anon, authenticated;

-- Helpful time/severity index for common filters
create index if not exists traffic_incidents_time_sev_idx
on public.traffic_incidents (observed_at desc, severity);
