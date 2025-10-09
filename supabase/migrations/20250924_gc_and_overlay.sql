-- 20250924_gc_and_overlay.sql
-- GC helper for 511 data and combined overlay + bbox RPC. Idempotent.

-- SQL GC helper
create or replace function public.gc_expired_511() returns void
language sql security definer as $$
  delete from public.road_closures where expires_at < now();
$$;
grant execute on function public.gc_expired_511() to service_role;

-- Normalize minimal fields for overlay
create or replace view public.v_incident_overlay as
select 'closure' as kind, state, severity, cause, start_time as start_ts, end_time as end_ts,
       last_seen, expires_at, geometry, meta
from public.road_closures
where expires_at > now()
union all
select 'weather' as kind, null::text as state, severity, kind as cause, onset as start_ts, null::timestamptz as end_ts,
       last_seen, expires_at, geometry, meta
from public.weather_hazards
where expires_at > now();

-- Simple bbox RPC (expects GeoJSON with coordinates)
create or replace function public.incident_overlay_in_bbox(
  w double precision, s double precision, e double precision, n double precision
) returns setof public.v_incident_overlay
language sql
security definer
as $$
  select * from public.v_incident_overlay vio
  where (vio.expires_at > now())
    and ((vio.geometry->>'type') in ('Point','MultiPoint','LineString','MultiLineString','Polygon','MultiPolygon'));
$$;
grant execute on function public.incident_overlay_in_bbox(double precision,double precision,double precision,double precision) to authenticated, anon;
