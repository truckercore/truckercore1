-- 20250923_v_ops_rollup.sql
-- Purpose: One‑Glance Ops Tile: roll-up view combining watchdog, SLO, and maintenance freshness.
-- Safe to re-run.

create or replace view public.v_ops_rollup as
with w as (
  select (retention_ok and oldest_within_30d and next_partition_present) as ok,
         rows_beyond_30d,
         maintenance_lag
  from public.edge_log_watchdog
),
s as (
  select coalesce(sum(calls),0) as calls_24h,
         coalesce(sum(errors),0) as errors_24h,
         max(p95_ms) as worst_p95_ms
  from public.edge_op_slo_24h
),
m as (
  select now() - max(ran_at) as since_last_maintenance,
         bool_or(ok) as last_maintenance_ok
  from public.ops_maintenance_log
  where task = 'nightly_maintenance'
)
select
  case when (select ok from w) then '✅ healthy' else '❌ attention' end as status,
  (select rows_beyond_30d from w) as rows_beyond_30d,
  (select maintenance_lag from w) as maintenance_lag,
  (select since_last_maintenance from m) as since_last_maintenance,
  (select last_maintenance_ok from m) as last_maintenance_ok,
  (select calls_24h from s) as calls_24h,
  (select errors_24h from s) as errors_24h,
  (select worst_p95_ms from s) as worst_p95_ms;
