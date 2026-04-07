-- 992_weekly_slo_report.sql
create or replace view public.weekly_slo_report as
select
  r.fn,
  count(*) as calls_7d,
  count(*) filter (where success) * 1.0 / greatest(count(*),1) as availability_7d,
  percentile_disc(0.95) within group (order by duration_ms) as p95_ms_7d,
  percentile_disc(0.50) within group (order by duration_ms) as p50_ms_7d,
  min(created_at) as window_start,
  max(created_at) as window_end
from public.function_audit_log r
where created_at >= now() - interval '7 days'
group by r.fn
order by r.fn;

-- Ensure routing exists for weekly report emails
insert into public.alert_routes(key, channel, dedupe_minutes, escalate_after_minutes, enabled)
values ('slo_weekly_report','email',1440,0,true)
on conflict (key) do update
  set channel=excluded.channel,
      dedupe_minutes=excluded.dedupe_minutes,
      escalate_after_minutes=excluded.escalate_after_minutes,
      enabled=excluded.enabled,
      updated_at=now();