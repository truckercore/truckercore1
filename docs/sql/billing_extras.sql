-- Billing extras: webhook idempotency, price map, grace helper, KPIs, sanity views
-- Idempotent and safe to re-run

-- 1) Webhook idempotency
create table if not exists public.stripe_events_dedup (
  id text primary key,              -- Stripe event id (evt_*) stored directly in id
  type text not null,
  received_at timestamptz not null default now()
);

-- 2) Ensure billing_profiles optional columns exist (compat)
alter table if exists public.billing_profiles
  add column if not exists stripe_subscription_id text,
  add column if not exists grace_until timestamptz;

-- 3) Price → entitlement map (single source of truth)
create table if not exists public.stripe_price_map (
  price_id text primary key,              -- price_*
  tier text not null check (tier in ('basic','premium','ai')),
  ai_enabled boolean not null default false,
  active boolean not null default true
);

-- Example placeholder rows (update with your real Stripe price ids)
insert into public.stripe_price_map (price_id, tier, ai_enabled, active)
values
  ('price_ai_example', 'ai', true, true),
  ('price_premium_example', 'premium', false, true)
on conflict (price_id) do nothing;

-- 4) Grace helper
create or replace function public.billing_set_grace(p_customer text, p_hours int default 72)
returns void language plpgsql as $$
begin
  update public.billing_profiles
  set grace_until = now() + make_interval(hours=>p_hours)
  where stripe_customer_id = p_customer and grace_until is null;
end $$;

-- 5) Sanity views
create or replace view public.v_price_catalog as
select p.price_id, p.tier, p.ai_enabled, p.active,
       (select count(*) from public.billing_profiles where tier=p.tier and ai_enabled=p.ai_enabled) as accounts
from public.stripe_price_map p;

-- 6) KPIs
create or replace view public.v_billing_kpis as
select
  (select count(*) from public.billing_profiles where coalesce(ai_enabled,false)) as ai_accounts,
  (select count(*) from public.stripe_events_dedup where received_at > now() - interval '24 hours') as webhooks_24h,
  (select count(*) from public.billing_profiles where updated_at > now() - interval '24 hours' and coalesce(ai_enabled,false)) as ai_activations_24h;
