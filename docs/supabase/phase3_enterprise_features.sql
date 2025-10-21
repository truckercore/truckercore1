-- Phase 3 — Enterprise Features (Schema Only)
-- Carrier/Broker Vetting, Shipper Portal, TMS/API Integrations
-- Safe to run multiple times with IF NOT EXISTS guards.

create extension if not exists "uuid-ossp";

-- =========================================================
-- Feature 7: Carrier/Broker Vetting Tools
-- =========================================================
create table if not exists public.carrier_verifications (
  id uuid primary key default uuid_generate_v4(),
  org_id uuid not null,
  mc_number text null,
  dot_number text null,
  insurance_provider text null,
  insurance_expiry date null,
  safety_rating text null check (safety_rating in ('satisfactory','conditional','unsatisfactory') or safety_rating is null),
  fraud_flag boolean not null default false,
  last_verified_at timestamptz not null default now()
);
create index if not exists idx_carrier_dot on public.carrier_verifications (dot_number);
create index if not exists idx_carrier_mc on public.carrier_verifications (mc_number);

alter table public.carrier_verifications enable row level security;
-- READ: all authenticated brokers can view carrier_verifications.
-- You may tailor this to your app's roles/claims; here we check a JWT roles array.
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='carrier_verifications' AND policyname='carrier_verifications_select') THEN
    CREATE POLICY carrier_verifications_select ON public.carrier_verifications
      FOR SELECT USING (
        ((current_setting('request.jwt.claims', true)::jsonb -> 'app_roles') ? 'broker')
      );
  END IF;
END $$;
-- WRITE: service role only (no insert/update/delete granted to anon/authenticated)
REVOKE INSERT, UPDATE, DELETE ON public.carrier_verifications FROM anon, authenticated;

-- =========================================================
-- Feature 8: Shipper Portal
-- =========================================================
-- Add role 'shipper' to profiles.roles (documented; not enforced here)
-- Shipper loads table
create table if not exists public.shipper_loads (
  id uuid primary key default uuid_generate_v4(),
  org_id uuid null,
  posted_by_user_id uuid null,
  origin_zip text null,
  dest_zip text null,
  equipment text null,
  pickup_date date null,
  delivery_date date null,
  offered_rate numeric(12,2) null,
  status text not null default 'open' check (status in ('open','assigned','cancelled')),
  created_at timestamptz not null default now()
);
create index if not exists idx_shipper_loads_org_status on public.shipper_loads (org_id, status);

alter table public.shipper_loads enable row level security;
-- RLS rules (expressed as example policies; adjust claims/columns to your auth model):
-- Shippers see only their org loads
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='shipper_loads' AND policyname='shipper_loads_select_shipper') THEN
    CREATE POLICY shipper_loads_select_shipper ON public.shipper_loads
      FOR SELECT USING (
        ((current_setting('request.jwt.claims', true)::jsonb -> 'app_roles') ? 'shipper')
        AND (
          (current_setting('request.jwt.claims', true)::jsonb ->> 'app_org_id')::uuid = coalesce(org_id, (current_setting('request.jwt.claims', true)::jsonb ->> 'app_org_id')::uuid)
        )
      );
  END IF;
END $$;
-- Brokers see open shipper loads (for bidding)
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='shipper_loads' AND policyname='shipper_loads_select_broker') THEN
    CREATE POLICY shipper_loads_select_broker ON public.shipper_loads
      FOR SELECT USING (
        ((current_setting('request.jwt.claims', true)::jsonb -> 'app_roles') ? 'broker') AND status = 'open'
      );
  END IF;
END $$;
-- Fleets/owner-ops see assigned shipper loads (assumes a join via assignments; simplify: allow when status='assigned')
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='shipper_loads' AND policyname='shipper_loads_select_assigned') THEN
    CREATE POLICY shipper_loads_select_assigned ON public.shipper_loads
      FOR SELECT USING (
        (
          ((current_setting('request.jwt.claims', true)::jsonb -> 'app_roles') ? 'carrier')
          OR ((current_setting('request.jwt.claims', true)::jsonb -> 'app_roles') ? 'owner_op')
        ) AND status = 'assigned'
      );
  END IF;
END $$;
-- WRITE policies (INSERT/UPDATE/DELETE) typically restricted to shippers of same org or service role. For mock-first, you may leave writes to service role only.
REVOKE INSERT, UPDATE, DELETE ON public.shipper_loads FROM anon, authenticated;

-- =========================================================
-- Feature 9: TMS/API Integrations — API Keys
-- =========================================================
create table if not exists public.api_keys (
  id uuid primary key default uuid_generate_v4(),
  org_id uuid not null,
  label text null,
  key_hash text not null,
  created_at timestamptz not null default now(),
  last_used_at timestamptz null,
  revoked boolean not null default false
);

alter table public.api_keys enable row level security;
-- READ/WRITE: only org admins can manage their keys
-- This example expects a JWT claim app_is_org_admin = true and app_org_id for scoping
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='api_keys' AND policyname='api_keys_select') THEN
    CREATE POLICY api_keys_select ON public.api_keys
      FOR SELECT USING (
        coalesce((current_setting('request.jwt.claims', true)::jsonb ->> 'app_org_id')::uuid, '00000000-0000-0000-0000-000000000000'::uuid) = org_id
        AND ((current_setting('request.jwt.claims', true)::jsonb ->> 'app_is_org_admin')::boolean = true)
      );
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='api_keys' AND policyname='api_keys_modify') THEN
    CREATE POLICY api_keys_modify ON public.api_keys
      FOR ALL USING (
        coalesce((current_setting('request.jwt.claims', true)::jsonb ->> 'app_org_id')::uuid, '00000000-0000-0000-0000-000000000000'::uuid) = org_id
        AND ((current_setting('request.jwt.claims', true)::jsonb ->> 'app_is_org_admin')::boolean = true)
      ) WITH CHECK (
        coalesce((current_setting('request.jwt.claims', true)::jsonb ->> 'app_org_id')::uuid, '00000000-0000-0000-0000-000000000000'::uuid) = org_id
        AND ((current_setting('request.jwt.claims', true)::jsonb ->> 'app_is_org_admin')::boolean = true)
      );
  END IF;
END $$;

-- Service role can validate on incoming requests — grant usage via Edge Functions only.
