-- Core billing linkage
create table if not exists public.billing_customers (
  org_id uuid primary key,
  stripe_customer_id text unique not null,
  created_at timestamptz default now()
);

create table if not exists public.billing_subscriptions (
  org_id uuid primary key,
  stripe_subscription_id text unique not null,
  tier text not null check (tier in ('basic','standard','premium','enterprise')),
  status text not null,
  current_period_end timestamptz,
  updated_at timestamptz default now()
);

-- Replay-resistance + audit
create table if not exists public.checkout_sessions (
  id bigserial primary key,
  org_id uuid not null,
  user_id uuid not null,
  stripe_session_id text unique not null,
  amount_total bigint,
  currency text,
  status text,
  created_at timestamptz default now()
);

create table if not exists public.paywall_nonces (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  user_id uuid not null,
  nonce text not null unique,
  expires_at timestamptz not null,
  used_at timestamptz,
  created_at timestamptz default now(),
  constraint nonce_not_expired check (expires_at > created_at)
);

create table if not exists public.stripe_webhook_events (
  event_id text primary key,
  type text not null,
  livemode boolean not null,
  received_at timestamptz default now(),
  payload jsonb not null,
  processed_at timestamptz,
  error text
);

-- Profile flags (ensure columns on your profiles table)
alter table public.profiles
  add column if not exists app_tier text default 'basic',
  add column if not exists app_is_premium boolean default false;

-- RLS enablement
alter table public.billing_customers enable row level security;
alter table public.billing_subscriptions enable row level security;
alter table public.checkout_sessions enable row level security;
alter table public.paywall_nonces enable row level security;

-- NOTE: Replace predicates with your org scoping rule if available later
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='billing_customers' AND policyname='cust.org_read'
  ) THEN
    CREATE POLICY "cust.org_read"
    ON public.billing_customers FOR SELECT
    USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='billing_subscriptions' AND policyname='subs.org_read'
  ) THEN
    CREATE POLICY "subs.org_read"
    ON public.billing_subscriptions FOR SELECT
    USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='checkout_sessions' AND policyname='sessions.self_read'
  ) THEN
    CREATE POLICY "sessions.self_read"
    ON public.checkout_sessions FOR SELECT
    USING (user_id = auth.uid());
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='paywall_nonces' AND policyname='nonces.self_rw'
  ) THEN
    CREATE POLICY "nonces.self_rw"
    ON public.paywall_nonces FOR ALL
    USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
  END IF;
END $$;

-- Helper RPCs
create or replace function public.mint_paywall_nonce(p_user uuid, p_org uuid, p_ttl_minutes int default 15)
returns table (nonce text, expires_at timestamptz)
language plpgsql
security definer
set search_path = public
as $$
declare v_nonce text := encode(gen_random_bytes(24),'hex');
begin
  insert into public.paywall_nonces (org_id,user_id,nonce,expires_at)
  values (p_org, p_user, v_nonce, now() + (p_ttl_minutes || ' minutes')::interval);
  return query select v_nonce, (now() + (p_ttl_minutes || ' minutes')::interval);
end $$;

revoke all on function public.mint_paywall_nonce(uuid,uuid,int) from public;
grant execute on function public.mint_paywall_nonce(uuid,uuid,int) to authenticated;

-- Indexes
create index if not exists idx_paywall_nonces_user_exp on public.paywall_nonces(user_id,expires_at) where used_at is null;
create index if not exists idx_checkout_sessions_org on public.checkout_sessions(org_id);
