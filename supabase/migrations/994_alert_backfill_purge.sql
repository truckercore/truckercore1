-- 994_alert_backfill_purge.sql
-- Backfill dedupe keys on older pending alerts and add a purge helper

-- Backfill dedupe keys on any older pending alerts
update public.alert_outbox a
set dedupe_key = a.key || ':' || public.json_sha256(a.payload)
where a.delivered_at is null
  and (a.dedupe_key is null or a.dedupe_key = '');

-- Auto-expire undelivered noise (optional)
create or replace function public.purge_stale_alerts(days int default 7)
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.alert_outbox
  where delivered_at is null
    and created_at < now() - (days || ' days')::interval
    and key not like '%_escalated';
$$;

-- Cron recap (for reference)
-- Every 5–10 min: select public.check_slo_alerts();
-- Every 10–15 min: select public.escalate_stale_alerts();
-- Every 5–10 min: call Edge Function notify-alerts via HTTP cron
-- Daily (optional): select public.purge_stale_alerts();
