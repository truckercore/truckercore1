begin;
create or replace function fleet_discounts_nearby(q_fleet uuid, q_lat double precision, q_lng double precision)
returns table (stop_org_id uuid, location_id uuid, fuel_cents int, def_cents int, km numeric, start_at timestamptz, end_at timestamptz)
language sql stable as $$
  with active as (
    select * from fleet_discounts
    where fleet_org_id = q_fleet and start_at <= now() and end_at >= now()
  ), locs as (
    select id as location_id, org_id, lat, lng,
     ( 6371 * acos( cos(radians(q_lat)) * cos(radians(lat)) * cos(radians(lng) - radians(q_lng)) + sin(radians(q_lat)) * sin(radians(lat)) ) ) as km
    from locations
  )
  select a.stop_org_id, l.location_id, a.fuel_cents, a.def_cents, l.km, a.start_at, a.end_at
  from active a join locs l on a.stop_org_id = l.org_id
  where l.km <= 50
  order by km asc limit 20;
$$;
grant execute on function fleet_discounts_nearby(uuid,double precision,double precision) to authenticated, service_role;
commit;
