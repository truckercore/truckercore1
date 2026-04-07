-- 20250924_hazards_overlay.sql
-- Option A — Unified Hazards overlay (DOT 511 + NOAA): schema + indexes + RLS + view + RPC
-- Idempotent and safe to re-run.

-- Ensure PostGIS
create extension if not exists postgis;

-- Hazards: traffic/road (DOT 511) and weather (NOAA)
create table if not exists public.hazards (
  id uuid primary key default gen_random_uuid(),
  source text not null check (source in ('dot511','noaa')),
  kind text not null,                       -- e.g., 'closure','construction','incident','flood','snow','wind'
  severity text null,                       -- e.g., 'minor','moderate','major'
  title text null,
  description text null,
  geom geometry(Geometry, 4326) not null,   -- points/lines/polygons
  starts_at timestamptz null,
  ends_at timestamptz null,
  observed_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);
create index if not exists idx_hazards_gix on public.hazards using gist (geom);
create index if not exists idx_hazards_observed_at on public.hazards (observed_at desc);

-- View for mobile: recent + simplified fields
create or replace view public.v_hazards_recent as
select id, source, kind, severity, title, description, starts_at, ends_at, observed_at,
       st_asgeojson(geom)::jsonb as geojson, metadata
from public.hazards
where observed_at >= now() - interval '7 days';

-- RLS: enable + read for authenticated
alter table public.hazards enable row level security;
create policy if not exists hazards_read_all on public.hazards for select to authenticated using (true);

-- Grants for view
grant select on public.v_hazards_recent to authenticated, anon;

-- SQL RPC (GeoJSON upsert helper)
create or replace function public.hazards_upsert_geojson(p_rows jsonb)
returns void language plpgsql security definer as $$
declare r jsonb; begin
  for r in select * from jsonb_array_elements(p_rows) loop
    insert into public.hazards (id, source, kind, severity, title, description,
      geom, starts_at, ends_at, observed_at, metadata)
    values (
      coalesce((r->>'id')::uuid, gen_random_uuid()),
      r->>'source',
      r->>'kind',
      nullif(r->>'severity',''),
      nullif(r->>'title',''),
      nullif(r->>'description',''),
      ST_SetSRID(ST_GeomFromGeoJSON(r->>'geom'), 4326),
      (r->>'starts_at')::timestamptz,
      (r->>'ends_at')::timestamptz,
      coalesce((r->>'observed_at')::timestamptz, now()),
      coalesce(r->'metadata','{}'::jsonb)
    )
    on conflict (id) do update
    set source = excluded.source,
        kind = excluded.kind,
        severity = excluded.severity,
        title = excluded.title,
        description = excluded.description,
        geom = excluded.geom,
        starts_at = excluded.starts_at,
        ends_at = excluded.ends_at,
        observed_at = excluded.observed_at,
        metadata = excluded.metadata;
  end loop;
end $$;

revoke all on function public.hazards_upsert_geojson(jsonb) from public;
grant execute on function public.hazards_upsert_geojson(jsonb) to service_role;
