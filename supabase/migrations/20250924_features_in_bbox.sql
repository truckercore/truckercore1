-- 20250924_features_in_bbox.sql
-- Bounding box RPC using PostGIS

create or replace function public.features_in_bbox(bbox geometry)
returns table(kind text, id uuid, name text, geo jsonb, meta jsonb)
language sql stable
as $$
  select 'weigh_station', w.id, w.name, st_asgeojson(w.location)::jsonb, w.facilities
  from public.weigh_stations w
  where st_intersects(w.location, bbox)
  union all
  select 'truck_stop', t.id, t.name, st_asgeojson(t.location)::jsonb, t.amenities
  from public.truck_stops t
  where st_intersects(t.location, bbox)
$$;

grant execute on function public.features_in_bbox(geometry) to anon, authenticated;
