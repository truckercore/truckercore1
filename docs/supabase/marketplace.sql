-- docs/supabase/marketplace.sql
-- Trust scores and incentives for marketplace liquidity loops. Idempotent and safe to re-run.

create extension if not exists pgcrypto;

-- Trust scores
create table if not exists public.market_trust (
  org_id uuid not null,
  actor_type text not null check (actor_type in ('broker','fleet','carrier')),
  actor_id uuid not null,
  score numeric(4,3) not null default 0.5,
  factors jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  primary key (org_id, actor_type, actor_id)
);

-- Incentives ledger
create table if not exists public.liquidity_incentives (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  side text not null check (side in ('broker','fleet')),
  actor_id uuid not null,
  incentive_type text not null check (incentive_type in ('boost','credit','fee_rebate')),
  value_cents int not null default 0,
  reason text not null,
  expires_at timestamptz null,
  created_at timestamptz not null default now()
);
create index if not exists idx_liq_incentives_org_actor on public.liquidity_incentives (org_id, side, actor_id);

-- RLS helpers
alter table public.market_trust enable row level security;
alter table public.liquidity_incentives enable row level security;

create or replace function public.jwt_claim(claim text)
returns text stable language sql as $$ select coalesce(current_setting('request.jwt.claims', true)::json->>claim, '') $$;

create policy if not exists market_trust_rw_org on public.market_trust
for all to authenticated
using (org_id::text = public.jwt_claim('app_org_id'))
with check (org_id::text = public.jwt_claim('app_org_id'));

create policy if not exists liq_incentives_rw_org on public.liquidity_incentives
for all to authenticated
using (org_id::text = public.jwt_claim('app_org_id'))
with check (org_id::text = public.jwt_claim('app_org_id'));
