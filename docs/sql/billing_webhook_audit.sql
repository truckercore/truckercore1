-- Webhook audit trail (Stripe) + billing alert KPIs and simulator
-- Idempotent and safe to re-run

-- 1) Audit table
create table if not exists public.stripe_webhook_audit (
  id text primary key,                 -- Stripe event id (evt_*)
  type text,
  payload jsonb,
  processed_at timestamptz not null default now(),
  status text not null check (status in ('success','dedup','error')),
  error text
);
create index if not exists idx_stripe_webhook_audit_time on public.stripe_webhook_audit (processed_at desc);

-- 2) Billing alerts (exec-friendly)
create or replace view public.v_billing_alerts as
select
  (select count(*) from public.stripe_webhook_audit
    where processed_at > now() - interval '1 hour' and status = 'error')        as webhook_errors_1h,
  (select count(*) from public.billing_profiles
    where coalesce(ai_enabled,false) and grace_until is not null and grace_until < now()) as grace_expired,
  (select count(*) from public.billing_profiles
    where coalesce(ai_enabled,false) and coalesce(tier,'') <> 'ai')             as entitlement_drift;

-- 3) Dry-run simulator (CI safety)
create or replace function public.billing_simulate(price_id text, sub_status text)
returns table(tier text, ai_enabled boolean, grace_until timestamptz)
language sql
stable
as $$
  select
    spm.tier,
    spm.ai_enabled,
    case when lower(sub_status) = 'past_due' then now() + interval '72 hours' end as grace_until
  from public.stripe_price_map spm
  where spm.price_id = billing_simulate.price_id
$$;

-- 4) Executive reporting panel (KPIs)
create or replace view public.v_revenue_kpis as
select
  count(*) filter (where tier = 'ai')          as ai_subs,
  count(*) filter (where tier = 'premium')     as premium_subs,
  count(*) filter (where grace_until > now())  as in_grace,
  count(*) filter (where coalesce(ai_enabled,false)) as ai_entitled
from public.billing_profiles;