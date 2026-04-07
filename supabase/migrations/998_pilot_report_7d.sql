create or replace view public.pilot_report_7d as
select
  (select count(*) from public.function_audit_log where created_at >= now()-interval '7 days') as fn_calls_7d,
  (select count(*) from public.function_audit_log where success=false and created_at >= now()-interval '7 days') as fn_errors_7d,
  (select round(avg(availability)::numeric, 4) from public.slo_fn_rolling_7d) as avg_availability_7d,
  (select round(avg(p95_ms)) from public.slo_fn_rolling_7d) as avg_p95_ms_7d,
  (select count(*) from public.alert_outbox where delivered_at is null) as pending_alerts,
  (select min(created_at) from public.alert_outbox where delivered_at is null) as oldest_pending_created_at;