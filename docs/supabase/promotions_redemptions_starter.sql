-- TruckerCore — Minimal Promotions & Redemptions SQL/RLS Starter
-- NOTE: Review and adapt before deploying to production.
-- - Default deny via RLS
-- - Do NOT use service_role keys in clients; invoke Edge Functions for sensitive flows

-- Extensions (Supabase defaults usually include these)
-- create extension if not exists pgcrypto; -- for gen_random_uuid()

-- 1) Organizations (simplified)
create table if not exists public.orgs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  tier text default 'free',
  metadata jsonb,
  created_at timestamptz not null default now()
);

-- 2) Locations (simplified)
create table if not exists public.locations (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id) on delete cascade,
  name text not null,
  lat double precision not null,
  lng double precision not null,
  address text,
  amenities jsonb,
  created_at timestamptz not null default now()
);

-- 3) Promotions
create table if not exists public.promotions (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id) on delete cascade,
  title text not null,
  description text,
  type text not null check (type in ('percent','amount')),
  value_cents integer not null default 0, -- if percent, store e.g. 10 => 10%
  location_ids uuid[] default '{}',
  start_at timestamptz not null,
  end_at timestamptz not null,
  rules jsonb, -- { per_user_limit, min_spend, hours, ... }
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 4) Promo Redemptions (write via Edge Function)
create table if not exists public.promo_redemptions (
  id uuid primary key default gen_random_uuid(),
  promo_id uuid not null references public.promotions(id) on delete cascade,
  user_id uuid not null,
  org_id uuid not null references public.orgs(id) on delete cascade,
  nonce text not null unique, -- one-time token/nonce for redemption
  subtotal_cents integer not null,
  discount_cents integer not null default 0,
  status text not null check (status in ('approved','rejected')),
  reason text,
  created_at timestamptz not null default now()
);

-- 5) Parking Status (operator updates)
create table if not exists public.parking_status (
  location_id uuid primary key references public.locations(id) on delete cascade,
  occupancy text not null check (occupancy in ('open','some','full')),
  spaces_total integer,
  spaces_free integer,
  source text default 'operator',
  updated_at timestamptz not null default now()
);

-- 6) Driver Invites (operator creates pending invites)
create table if not exists public.driver_invites (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  org_id uuid not null references public.orgs(id) on delete cascade,
  role text not null,
  status text not null default 'pending',
  created_at timestamptz not null default now()
);

-- RLS: enable and default deny
alter table public.promotions enable row level security;
alter table public.promo_redemptions enable row level security;
alter table public.parking_status enable row level security;
alter table public.driver_invites enable row level security;

-- Helper (pseudo) function used in policies (implement per your auth model)
-- expects JWT claims to include app_org_id / roles, or use a memberships table
-- create or replace function public.is_member_of_org(org uuid)
-- returns boolean as $$ select true $$ language sql stable; -- TODO: replace

-- Promotions Policies
-- Drivers & operators can select org-scoped rows
create policy if not exists sel_promotions_org on public.promotions
  for select using (
    auth.role() = 'authenticated' and true -- TODO: replace with org-membership check
  );

-- Operators can insert/update within their org (example: gate by custom claim)
create policy if not exists ins_promotions_operator on public.promotions
  for insert with check (
    auth.role() = 'authenticated' -- AND is_operator_in_org(org_id)
  );
create policy if not exists upd_promotions_operator on public.promotions
  for update using (
    auth.role() = 'authenticated'
  ) with check (
    auth.role() = 'authenticated'
  );

-- Promo Redemptions Policies
-- Clients should not insert directly; use Edge Function running as service role
create policy if not exists sel_redemptions_self on public.promo_redemptions
  for select using (
    auth.uid() = user_id
  );
-- Optional: allow insert only via SECURITY DEFINER function or service role
-- revoke insert on table public.promo_redemptions from anon, authenticated;

-- Parking Status Policies
create policy if not exists sel_parking_status_all on public.parking_status
  for select using (true);
create policy if not exists upsert_parking_operator on public.parking_status
  for all using (
    auth.role() = 'authenticated' -- TODO: tighten to operator roles
  ) with check (
    auth.role() = 'authenticated'
  );

-- Driver Invites Policies (read own by email via SECURE VIEW recommended)
create policy if not exists sel_driver_invites_none on public.driver_invites
  for select using (false);
create policy if not exists ins_driver_invites_operator on public.driver_invites
  for insert with check (auth.role() = 'authenticated');

-- Edge Functions Contract (Deno) — to be implemented server-side
-- 1) promotions-issue-qr: input { promo_id }
--    - Mint short-lived JWT with nonce, promo_id, user_id, org_id, exp
--    - Store nonce (prevent replay)
--    - Return { token, nonce, exp }
-- 2) promotions-redeem: input { token, cashier_id, subtotal_cents }
--    - Verify JWT + nonce
--    - Enforce per-user/org limits
--    - Calculate discount
--    - Insert promo_redemptions row
--    - Return { status, discount_cents }

-- Analytics example function (skeleton)
-- create or replace function public.analytics_location_kpis(location_id uuid)
-- returns jsonb language sql stable as $$ select jsonb_build_object('redemptions', 0) $$;
