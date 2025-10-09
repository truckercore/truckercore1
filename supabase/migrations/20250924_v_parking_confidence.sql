-- 20250924_v_parking_confidence.sql
-- Confidence fusion view for parking

create or replace view public.v_parking_confidence as
select
  t.id,
  t.name,
  t.brand,
  st_asgeojson(t.location)::jsonb as geo,
  avg(p.occupancy_pct) filter (where p.source = 'partner') as partner_est,
  avg(p.occupancy_pct) filter (where p.source = 'crowd')   as crowd_est,
  greatest(max(p.observed_at), max(c.observed_at))         as last_update,
  coalesce(avg(p.occupancy_pct), avg(c.occupancy_pct))     as blended_est
from public.truck_stops t
left join public.parking_status p on p.stop_id = t.id
left join public.crowd_reports c on c.stop_id = t.id and c.kind = 'parking'
group by t.id, t.name, t.brand, t.location;
