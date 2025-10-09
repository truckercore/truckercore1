-- 20250924_edge_log_status_views.sql
-- Purpose: Operator-friendly tile, SLO roll-up view, and status view joining watchdog + SLO.
-- Safe to re-run (CREATE OR REPLACE, IF NOT EXISTS).

-- 1) Overall SLO roll-up across all ops for the last 24h
--    Produces a single row with bucket='24h', p95_ms and error_rate (errors/calls).
create or replace view public.edge_request_slo as
with base as (
  select count(*) as calls,
         count(*) filter (where status >= 500) as errors,
         percentile_cont(0.95) within group (order by ms) as p95_ms
  from public.edge_request_log
  where ts >= now() - interval '24 hours'
)
select '24h'::text as bucket,
       b.p95_ms,
       (b.errors::decimal / nullif(b.calls,0)) as error_rate
from base b;

-- 2) Status view joining watchdog and SLO roll-up (as per issue description)
create or replace view public.edge_log_status as
select w.*, s.p95_ms, s.error_rate
from public.edge_log_watchdog w
left join public.edge_request_slo s on s.bucket = '24h';

-- 3) Operator-friendly tile: maps booleans to a quick status label
create or replace view public.edge_log_tile as
select case
         when (retention_ok and oldest_within_30d and next_partition_present)
         then '✅ healthy'
         else '❌ needs attention'
       end as edge_log_status,
       rows_beyond_30d,
       oldest_row_ts,
       last_maintenance_at,
       maintenance_lag
from public.edge_log_watchdog;
