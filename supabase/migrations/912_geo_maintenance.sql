create or replace function public.weekly_geo_maintenance()
returns void language plpgsql security definer set search_path=public as $$
begin
  perform pg_stat_reset();
  -- Analyze first for planner stats
  perform (select pg_catalog.pg_sleep(0));
  execute 'analyze public.loads';
  -- Reindex only the spatial index to avoid table locks where possible
  -- Ensure the index name matches your migration (idx_loads_pickup_geom)
  execute 'reindex index concurrently if exists idx_loads_pickup_geom';
  -- Vacuum analyze for bloat + stats
  execute 'vacuum (analyze) public.loads';
end;
$$;
