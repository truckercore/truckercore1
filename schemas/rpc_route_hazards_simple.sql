-- route_hazards_simple(polyline json, trailer_height_ft numeric)
-- polyline format: [[lat, lng], [lat, lng], ...]
-- Returns setof jsonb with fields: id, state_code, category, description, location
-- This is a simplified implementation using bbox intersection for performance.

create or replace function public.route_hazards_simple(
  polyline json,
  trailer_height_ft numeric default null
)
returns setof jsonb
language plpgsql
stable
as $$
declare
  pts json;
  lat double precision;
  lng double precision;
  i int := 0;
  n int;
  route geometry;
  bbox geometry;
  has_postgis boolean;
begin
  -- Check PostGIS availability
  select exists (select 1 from pg_extension where extname='postgis') into has_postgis;

  if not has_postgis then
    -- Fallback: we cannot compute intersections; return empty set
    return;
  end if;

  -- Build a LINESTRING from the input points
  n := json_array_length(polyline);
  if n < 2 then
    return; -- need at least two points
  end if;

  -- Construct WKT string for the line with SRID 4326
  -- Example: LINESTRING(-71.1 42.3, -71.2 42.35, ...)
  declare
    wkt text := 'LINESTRING(';
  begin
    while i < n loop
      lat := (polyline -> i -> 0)::text::double precision;
      lng := (polyline -> i -> 1)::text::double precision;
      if i > 0 then wkt := wkt || ', '; end if;
      wkt := wkt || (lng::text || ' ' || lat::text);
      i := i + 1;
    end loop;
    wkt := wkt || ')';
    route := ST_SetSRID(ST_GeomFromText(wkt), 4326);
  end;

  -- Expand route to a small buffer (e.g., ~50 meters) to catch near-by points
  bbox := ST_Envelope(ST_Buffer(route::geography, 50)::geometry);

  -- Return restrictions whose geom intersects bbox, or whose location json falls within bbox
  return query
  with candidates as (
    select r.id, r.state_code, r.category, r.description,
           coalesce(
             r.location,
             case when r.geom is not null then jsonb_build_object('lat', ST_Y(r.geom), 'lng', ST_X(r.geom)) end
           ) as location,
           r.geom
    from public.truck_restrictions r
    where
      (r.geom is not null and ST_Intersects(r.geom, bbox))
      or (
        r.geom is null and r.location ? 'lat' and r.location ? 'lng'
        and (r.location->>'lng')::double precision between ST_XMin(bbox) and ST_XMax(bbox)
        and (r.location->>'lat')::double precision between ST_YMin(bbox) and ST_YMax(bbox)
      )
  )
  select to_jsonb(c.*) from candidates c;
end;
$$;

comment on function public.route_hazards_simple(json, numeric) is 'Returns restriction rows intersecting a route polyline bbox; simple compliance surface.';