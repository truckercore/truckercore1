-- 20250930_stripe_referrals_metrics_insurance.sql
-- Idempotent migration to add Stripe subscription tracking, referral events, metrics, insurance quotes, and demo flag.

create extension if not exists pgcrypto;

-- Stripe subscriptions
create table if not exists public.stripe_subscriptions (
  id text primary key, -- Stripe subscription ID
  org_id uuid not null,
  customer_id text not null,
  price_id text not null,
  status text not null check (status in ('incomplete','incomplete_expired','trialing','active','past_due','canceled','unpaid')),
  current_period_start timestamptz not null,
  current_period_end timestamptz not null,
  cancel_at_period_end boolean not null default false,
  canceled_at timestamptz,
  trial_end timestamptz,
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_stripe_subs_org on public.stripe_subscriptions (org_id);
create index if not exists idx_stripe_subs_customer on public.stripe_subscriptions (customer_id);
alter table public.stripe_subscriptions enable row level security;
create policy if not exists stripe_subs_org on public.stripe_subscriptions
for select to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

-- Stripe customers
create table if not exists public.stripe_customers (
  id text primary key, -- Stripe customer ID
  org_id uuid not null unique,
  email text,
  name text,
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_stripe_customers_org on public.stripe_customers (org_id);
alter table public.stripe_customers enable row level security;
create policy if not exists stripe_customers_org on public.stripe_customers
for select to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

-- Referrals (marketplace revenue share)
create table if not exists public.referrals (
  id uuid primary key default gen_random_uuid(),
  referrer_code text not null unique,
  referrer_org_id uuid,
  referrer_type text check (referrer_type in ('partner','affiliate','integration')),
  referred_org_id uuid not null,
  stripe_customer_id text,
  revenue_share_pct numeric(5,2) not null default 10.00 check (revenue_share_pct >= 0 and revenue_share_pct <= 100),
  utm_source text,
  utm_campaign text,
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_referrals_referrer_org on public.referrals (referrer_org_id);
create index if not exists idx_referrals_referred_org on public.referrals (referred_org_id);
create index if not exists idx_referrals_code on public.referrals (referrer_code);

-- Metrics events
create table if not exists public.metrics_events (
  id bigserial primary key,
  kind text not null,
  value numeric default 1,
  labels jsonb default '{}'::jsonb,
  props jsonb default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_metrics_kind_time on public.metrics_events (kind, created_at desc);
create index if not exists idx_metrics_labels_gin on public.metrics_events using gin (labels);

-- Insurance quotes (Next Insurance stub)
create table if not exists public.insurance_quotes (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  user_id uuid not null,
  provider text not null default 'next_insurance',
  quote_data jsonb not null,
  premium_usd numeric(10,2),
  status text not null default 'draft' check (status in ('draft','quoted','bound','expired')),
  external_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_insurance_quotes_org_time on public.insurance_quotes (org_id, created_at desc);
alter table public.insurance_quotes enable row level security;
create policy if not exists insurance_quotes_org on public.insurance_quotes
for all to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''))
with check (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

-- Demo data flag on driver_profiles
alter table public.driver_profiles add column if not exists is_demo boolean not null default false;
create index if not exists idx_driver_profiles_demo on public.driver_profiles (is_demo) where is_demo = true;

-- RPC helper: update_org_premium_flag
create or replace function public.update_org_premium_flag(p_org_id uuid, p_premium boolean, p_plan text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Example: mark related profiles as premium; adjust to your schema as needed
  update public.driver_profiles
  set premium = coalesce(p_premium, false),
      trust_score = case when p_premium then greatest(coalesce(trust_score,0), 0.75) else trust_score end
  where org_id = p_org_id;
end $$;

revoke all on function public.update_org_premium_flag(uuid,boolean,text) from public;
grant execute on function public.update_org_premium_flag(uuid,boolean,text) to service_role;