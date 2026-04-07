-- docs/sql/kpis_roi_timings.sql
create or replace view public.v_fn_slo_24h as
select
  fn,
  count(*)                                                           as calls,
  sum((status = 'error')::int)::float / greatest(count(*), 1)        as error_rate,
  percentile_disc(0.5) within group (order by ms)                    as p50_ms,
  percentile_disc(0.95) within group (order by ms)                   as p95_ms
from public.function_invocations
where at > now() - interval '24 hours'
group by fn
order by p95_ms desc;
