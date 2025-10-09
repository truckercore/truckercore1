-- 993_sla_conformance.sql
create or replace view public.sla_conformance_30d as
select fn,
  count(*) as calls_30d,
  round(count(*) filter (where success) * 100.0 / greatest(count(*),1), 3) as avail_pct_30d,
  percentile_disc(0.95) within group (order by duration_ms) as p95_ms_30d
from public.function_audit_log
where created_at >= now() - interval '30 days'
group by fn
order by fn;