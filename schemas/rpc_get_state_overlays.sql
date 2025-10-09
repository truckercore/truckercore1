-- get_state_overlays(state_code text)
-- Returns overlays compatible with app expectations: id, state_code, category, description, location
-- If PostGIS geom is present, also include a computed centroid lat/lng in location if missing.

create or replace function public.get_state_overlays(state_code text)
returns setof jsonb
language sql
stable
as $$
  with base as (
    select id, state_code, category, description, location, geom
    from public.truck_restrictions
    where state_code = upper(state_code)
  ), enriched as (
    select
      id,
      state_code,
      category,
      description,
      case
        when location is not null then location
        when geom is not null then jsonb_build_object(
          'lat', ST_Y(geom::geometry),
          'lng', ST_X(geom::geometry)
        )
        else null
      end as location
    from base
  )
  select to_jsonb(e) from enriched e;
$$;

comment on function public.get_state_overlays(text) is 'Returns JSONB rows for truck restrictions by state.';