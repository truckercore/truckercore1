-- Observability quick add: health view for tiles
create or replace view tiles_health as
select coalesce(extract(epoch from (now()-max(updated_at)))::int, -1) as sec_lag,
       max(window_start) as last_window_start,
       count(*) as rows_total
from tiles_speed_agg;
