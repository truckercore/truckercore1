-- SQL RPC helpers for POI bbox queries
create or replace function poi_parking_bbox(minlng double precision, minlat double precision, maxlng double precision, maxlat double precision)
returns table (poi_id uuid, name text, state jsonb, confidence numeric, updated_at timestamptz)
language sql stable as $$
  select p.id, p.name, s.state, s.confidence, s.updated_at
  from pois p
  join poi_state s on s.poi_id = p.id
  where p.kind = 'parking'
    and st_intersects(p.geom, st_makeenvelope(minlng, minlat, maxlng, maxlat, 4326));
$$;

create or replace function poi_weigh_bbox(minlng double precision, minlat double precision, maxlng double precision, maxlat double precision)
returns table (poi_id uuid, name text, state jsonb, confidence numeric, updated_at timestamptz)
language sql stable as $$
  select p.id, p.name, s.state, s.confidence, s.updated_at
  from pois p
  join poi_state s on s.poi_id = p.id
  where p.kind = 'weigh'
    and st_intersects(p.geom, st_makeenvelope(minlng, minlat, maxlng, maxlat, 4326));
$$;
