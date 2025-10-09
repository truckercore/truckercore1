-- supabase/seeds/seed_tc_quality.sql
-- Idempotent seed for quality dashboard. Safe to re-run on dev.

-- Ensure at least two alerts
insert into public.alerts (id, title, description, severity, status)
values
  (gen_random_uuid(), 'Brake temperature spike', 'Sensor flagged elevated temps on I-80', 'high', 'open'),
  (gen_random_uuid(), 'ELD sync delayed', 'Device heartbeat late by 15m', 'medium', 'ack')
on conflict do nothing;

-- Pick two alerts for downstream seeds
with a as (
  select id from public.alerts order by created_at limit 2
)
insert into public.escalation_logs (id, alert_id, org_id, owner_id, owner_name, title, status)
select gen_random_uuid(), id, gen_random_uuid(), null, 'Moise', 'Initial escalation', 'open'
from a
on conflict do nothing;

-- Retest schedule (next week) for one alert
insert into public.retests (id, alert_id, retest_status, next_retest_at, last_retested_at)
select gen_random_uuid(), id, 'scheduled', current_date + 7, null
from (select id from public.alerts order by created_at limit 1) x
on conflict do nothing;

-- Remediation record (past month) for one alert
insert into public.remediations (id, alert_id, fix_title, deployed_at, verification_status)
select gen_random_uuid(), id, 'Firmware patch 1.2.3', date_trunc('day', now())::date - 30, 'verified_pass'
from (select id from public.alerts order by created_at limit 1) x
on conflict do nothing;

-- Report OK with counts for CLI visibility
select 'OK' as status,
  (select count(*) from public.alerts) as alerts,
  (select count(*) from public.escalation_logs) as escalations,
  (select count(*) from public.retests) as retests,
  (select count(*) from public.remediations) as remediations;
