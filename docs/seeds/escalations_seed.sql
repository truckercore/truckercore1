-- docs/seeds/escalations_seed.sql
-- Idempotent seed for alerts/escalation_logs/retests/remediations to support UI smoke tests.
-- Safe to re-run.

-- Simulate one org UUID for testing (replace later if needed)
select gen_random_uuid() as org INTO TEMP TABLE _org;

-- Alerts (example baseline)
insert into public.alerts (id, title, description, severity, status)
values
  (gen_random_uuid(), 'Brake temperature spike', 'Sensor flagged elevated temps on I-80', 'high', 'open'),
  (gen_random_uuid(), 'ELD sync delayed', 'Device heartbeat late by 15m', 'medium', 'ack')
on conflict do nothing;

-- Use two alert ids for escalations
with a as (
  select id from public.alerts order by created_at limit 2
)
insert into public.escalation_logs (id, alert_id, org_id, owner_id, owner_name, title, status)
select gen_random_uuid(), id, (select org from (select * from _org) o(org) limit 1), null, 'Moise', 'Initial escalation', 'open'
from a
on conflict do nothing;

-- Retest schedule (next week)
insert into public.retests (id, alert_id, retest_status, next_retest_at, last_retested_at)
select gen_random_uuid(), id, 'scheduled', current_date + 7, null
from (select id from public.alerts order by created_at limit 1) x
on conflict do nothing;

-- Remediation record (past month)
insert into public.remediations (id, alert_id, fix_title, deployed_at, verification_status)
select gen_random_uuid(), id, 'Firmware patch 1.2.3', date_trunc('day', now())::date - 30, 'verified_pass'
from (select id from public.alerts order by created_at limit 1) x
on conflict do nothing;

-- Note: if multi‑tenant, set org_id to a real org and ensure tester JWT app_org_id matches.
