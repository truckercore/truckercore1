begin;
create or replace function roadside_find_providers(q_lat double precision, q_lng double precision, q_service text)
returns table (provider_id uuid, name text, km numeric, services text[])
language sql stable as $$
  with p as (
    select id, name, services, lat, lng, radius_km,
    ( 6371 * acos( cos(radians(q_lat)) * cos(radians(lat)) * cos(radians(lng) - radians(q_lng)) + sin(radians(q_lat)) * sin(radians(lat)) ) ) as km
    from roadside_providers
    where services @> array[q_service]
  )
  select id, name, km, services from p where km <= radius_km order by km asc limit 20;
$$;
grant execute on function roadside_find_providers(double precision,double precision,text) to anon, authenticated, service_role;
commit;
