-- 988_audit_latency_slo.sql

-- 1) Add duration column to function_audit_log (idempotent)
alter table public.function_audit_log
  add column if not exists duration_ms integer;

-- 2) Rolling SLO windows (availability & latency)

-- Last 1 hour
create or replace view public.slo_fn_rolling_1h as
select
  fn,
  count(*) as calls,
  count(*) filter (where success) * 1.0 / greatest(count(*), 1) as availability,
  percentile_disc(0.95) within group (order by duration_ms) as p95_ms,
  percentile_disc(0.50) within group (order by duration_ms) as p50_ms
from public.function_audit_log
where created_at >= now() - interval '1 hour'
group by fn;

-- Last 7 days
create or replace view public.slo_fn_rolling_7d as
select
  fn,
  count(*) as calls,
  count(*) filter (where success) * 1.0 / greatest(count(*), 1) as availability,
  percentile_disc(0.95) within group (order by duration_ms) as p95_ms,
  percentile_disc(0.50) within group (order by duration_ms) as p50_ms
from public.function_audit_log
where created_at >= now() - interval '7 days'
group by fn;
