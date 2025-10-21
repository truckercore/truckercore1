-- docs/supabase/bi_heatmap.sql
-- Parking heatmap materialized view and optional refresh function. Idempotent.

-- Materialized view based on parking_state last_update; adapt if you have a richer events table
create materialized view if not exists public.mv_parking_heatmap as
select
  ps.poi_id,
  extract(dow from ps.last_update)::int as dow,
  extract(hour from ps.last_update)::int as hour,
  avg(case ps.occupancy when 'full' then 1 when 'some' then 0.7 when 'open' then 0.2 else 0.5 end) as fill_score
from public.parking_state ps
group by ps.poi_id, extract(dow from ps.last_update), extract(hour from ps.last_update);

-- Indexes to speed lookups
create index if not exists idx_mv_heatmap_poi on public.mv_parking_heatmap(poi_id);

-- Optional refresh helper (call from a scheduler after upstream changes)
create or replace function public.refresh_mv_parking_heatmap()
returns void language sql as $$
  refresh materialized view concurrently public.mv_parking_heatmap;
$$;
