create or replace function public.nearby_loads(lat double precision, lng double precision, radius_miles double precision)
returns table (
  id uuid,
  origin_city text,
  dest_city text,
  pickup_lat double precision,
  pickup_lng double precision,
  miles numeric,
  rate_usd numeric,
  distance_miles numeric
) language sql stable set search_path=public as $$
  with origin as (select geography(st_setsrid(st_makepoint(lng, lat), 4326)) as g)
  select l.id, l.origin_city, l.dest_city, l.pickup_lat, l.pickup_lng, l.miles, l.rate_usd,
         (st_distance(l.pickup_geom, o.g) / 1609.34)::numeric as distance_miles
  from public.loads l, origin o
  where l.pickup_geom is not null
    and st_dwithin(l.pickup_geom, o.g, radius_miles * 1609.34)
  order by st_distance(l.pickup_geom, o.g)
$$;
