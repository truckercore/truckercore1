create or replace view v_slow_rpc as
select query, calls, mean_exec_time
from pg_stat_statements
where query ilike '%state_parking_in_bbox%'
  and mean_exec_time > 50;