-- Billing health & monitoring views (idempotent)

-- Nightly CS follow-up: grace windows
create or replace view public.v_grace_expiring_3d as
select user_id, stripe_customer_id, grace_until
from public.billing_profiles
where grace_until between now() and now() + interval '72 hours'
order by grace_until asc;

-- Webhook errors last hour (for alerting)
create or replace view public.v_webhook_errors_1h as
select count(*) as webhook_errors_1h
from public.stripe_webhook_audit
where status = 'error' and processed_at >= now() - interval '1 hour';

-- Executive slice: flow health (24h volume + 1h errors)
create or replace view public.v_billing_flow_24h as
select
  (select count(*) from public.stripe_webhook_audit where processed_at >= now() - interval '24 hours') as webhooks_24h,
  (select count(*) from public.stripe_webhook_audit where status='error' and processed_at >= now() - interval '1 hour') as webhook_errors_1h;
