-- docs/supabase/poi_state_audit_kyc_escrow.sql
-- Safe-to-rerun scaffold aligning with the issue requirements.
-- This script is defensive: it creates objects only if missing and augments existing ones without breaking changes.

-- Extensions
create extension if not exists pgcrypto;
create extension if not exists cube;
create extension if not exists earthdistance;

-- =====================================================================
-- public.pois + indexes + RLS (only if missing)
-- =====================================================================
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='pois'
  ) THEN
    EXECUTE $$
      create table if not exists public.pois (
        id uuid primary key default gen_random_uuid(),
        name text not null,
        kind text not null check (kind in ('truck_stop','rest_area','weigh_station','wash','repair','fuel')),
        lat double precision not null,
        lng double precision not null,
        org_id uuid null,
        metadata jsonb not null default '{}'::jsonb,
        created_at timestamptz not null default now()
      )
    $$;
  ELSE
    -- Ensure helpful columns/indexes/rls if table already exists (different schema tolerated)
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='pois' AND column_name='metadata'
    ) THEN
      BEGIN
        ALTER TABLE public.pois ADD COLUMN metadata jsonb not null default '{}'::jsonb;
      EXCEPTION WHEN duplicate_column THEN NULL; END;
    END IF;
  END IF;
END $$;

create index if not exists idx_pois_kind on public.pois(kind);
-- Earthdistance GiST (works without PostGIS)
DO $$ BEGIN
  EXECUTE 'create index if not exists idx_pois_earth on public.pois using gist (ll_to_earth(lat,lng))';
EXCEPTION WHEN undefined_function THEN
  -- ll_to_earth not available; skip
  NULL;
END $$;

-- RLS read-all for authenticated
alter table public.pois enable row level security;
DO $$ BEGIN
  DROP POLICY IF EXISTS pois_read_all ON public.pois;
  CREATE POLICY pois_read_all ON public.pois
  FOR SELECT TO authenticated
  USING (true);
END $$;

-- =====================================================================
-- parking_state / weigh_station_state ensure + read policies
-- =====================================================================
create table if not exists public.parking_state (
  poi_id uuid primary key references public.pois(id) on delete cascade,
  occupancy text not null check (occupancy in ('open','some','full','unknown')),
  confidence numeric(4,3) not null default 0.5,
  last_update timestamptz not null default now(),
  source_mix jsonb not null default '{}'::jsonb
);
create table if not exists public.weigh_station_state (
  poi_id uuid primary key references public.pois(id) on delete cascade,
  status text not null check (status in ('open','closed','bypass','unknown')),
  confidence numeric(4,3) not null default 0.5,
  last_update timestamptz not null default now(),
  source_mix jsonb not null default '{}'::jsonb
);

alter table public.parking_state enable row level security;
alter table public.weigh_station_state enable row level security;
DO $$ BEGIN
  DROP POLICY IF EXISTS parking_state_read_all ON public.parking_state;
  CREATE POLICY parking_state_read_all ON public.parking_state FOR SELECT TO authenticated USING (true);
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS weigh_state_read_all ON public.weigh_station_state;
  CREATE POLICY weigh_state_read_all ON public.weigh_station_state FOR SELECT TO authenticated USING (true);
END $$;

-- =====================================================================
-- parking_forecast (skeleton) + RLS select
-- =====================================================================
create table if not exists public.parking_forecast (
  poi_id uuid not null references public.pois(id) on delete cascade,
  dow smallint not null check (dow between 0 and 6),        -- 0=Sun
  hour smallint not null check (hour between 0 and 23),
  p_open numeric(4,3) not null default 0.33,
  p_some numeric(4,3) not null default 0.33,
  p_full numeric(4,3) not null default 0.34,
  eta_80pct interval null,                                   -- predicted time to 80% full
  updated_at timestamptz not null default now(),
  primary key (poi_id, dow, hour)
);
alter table public.parking_forecast enable row level security;
DO $$ BEGIN
  DROP POLICY IF EXISTS parking_forecast_read_all ON public.parking_forecast;
  CREATE POLICY parking_forecast_read_all ON public.parking_forecast FOR SELECT TO authenticated USING (true);
END $$;

-- =====================================================================
-- audit_log helper (table augment + security definer function)
-- =====================================================================
create table if not exists public.audit_log (
  id uuid primary key default gen_random_uuid(),
  org_id uuid null,
  actor_user_id uuid null,
  action text not null,
  entity text not null,
  entity_id text not null,
  diff jsonb null,
  ip text null,
  ua text null,
  trace_id text null,
  created_at timestamptz not null default now()
);
create index if not exists idx_audit_org_time on public.audit_log (org_id, created_at desc);
alter table public.audit_log enable row level security;

-- Add missing columns compatibly (handle prior scaffold with ip inet or no trace_id)
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='audit_log' AND column_name='trace_id'
  ) THEN
    ALTER TABLE public.audit_log ADD COLUMN trace_id text null;
  END IF;
END $$;

-- Read policy (org-scoped)
DO $$ BEGIN
  DROP POLICY IF EXISTS audit_read_org ON public.audit_log;
  CREATE POLICY audit_read_org ON public.audit_log
  FOR SELECT TO authenticated
  USING (coalesce(org_id::text,'') = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
END $$;

-- Security definer helper; allow service role to insert freely
-- The function adapts to ip column type (text or inet) at runtime via dynamic SQL.
CREATE OR REPLACE FUNCTION public.fn_audit_insert(
  p_org_id uuid,
  p_actor_user_id uuid,
  p_action text,
  p_entity text,
  p_entity_id text,
  p_diff jsonb default null,
  p_ip text default null,
  p_ua text default null,
  p_trace_id text default null
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE v_id uuid; v_ip_is_inet boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='audit_log' AND column_name='ip' AND data_type='inet'
  ) INTO v_ip_is_inet;

  IF v_ip_is_inet THEN
    EXECUTE $$
      INSERT INTO public.audit_log (org_id, actor_user_id, action, entity, entity_id, diff, ip, ua, trace_id)
      VALUES ($1,$2,$3,$4,$5,$6,($7)::inet,$8,$9)
      RETURNING id
    $$ USING p_org_id, p_actor_user_id, p_action, p_entity, p_entity_id, p_diff, p_ip, p_ua, p_trace_id
    INTO v_id;
  ELSE
    INSERT INTO public.audit_log (org_id, actor_user_id, action, entity, entity_id, diff, ip, ua, trace_id)
    VALUES (p_org_id, p_actor_user_id, p_action, p_entity, p_entity_id, p_diff, p_ip, p_ua, p_trace_id)
    RETURNING id INTO v_id;
  END IF;

  RETURN v_id;
END $$;

-- Lock down and grant to service_role
REVOKE ALL ON FUNCTION public.fn_audit_insert(uuid,uuid,text,text,text,jsonb,text,text,text) FROM public;
GRANT EXECUTE ON FUNCTION public.fn_audit_insert(uuid,uuid,text,text,text,jsonb,text,text,text) TO service_role;

-- Optional: limited insert policy for authenticated users when org matches claim
DO $$ BEGIN
  DROP POLICY IF EXISTS audit_insert_scoped ON public.audit_log;
  CREATE POLICY audit_insert_scoped ON public.audit_log
  FOR INSERT TO authenticated
  WITH CHECK (coalesce(org_id::text,'') = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
END $$;

-- =====================================================================
-- KYC-lite, escrow skeletons
-- =====================================================================
create table if not exists public.kyc_verifications (
  user_id uuid primary key,
  provider text not null,
  status text not null check (status in ('pending','approved','rejected')),
  risk_score numeric(4,3) null,
  checks jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.kyc_verifications enable row level security;
DO $$ BEGIN
  DROP POLICY IF EXISTS kyc_self_read ON public.kyc_verifications;
  CREATE POLICY kyc_self_read ON public.kyc_verifications FOR SELECT TO authenticated USING (user_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'sub',''));
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS kyc_self_upsert ON public.kyc_verifications;
  CREATE POLICY kyc_self_upsert ON public.kyc_verifications FOR INSERT TO authenticated WITH CHECK (user_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'sub',''));
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS kyc_self_update ON public.kyc_verifications;
  CREATE POLICY kyc_self_update ON public.kyc_verifications FOR UPDATE TO authenticated USING (user_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'sub','')) WITH CHECK (user_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'sub',''));
END $$;

create table if not exists public.escrow_accounts (
  id uuid primary key default gen_random_uuid(),
  load_id uuid not null,
  payer_org_id uuid not null,
  payee_org_id uuid not null,
  amount_cents int not null check (amount_cents > 0),
  status text not null check (status in ('created','funded','in_transit','released','refunded','disputed')),
  provider text null,
  provider_ref text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_escrow_load on public.escrow_accounts (load_id);
alter table public.escrow_accounts enable row level security;
DO $$ BEGIN
  DROP POLICY IF EXISTS escrow_read_org ON public.escrow_accounts;
  CREATE POLICY escrow_read_org ON public.escrow_accounts
  FOR SELECT TO authenticated
  USING (
    payer_org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','')
    OR payee_org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','')
  );
END $$;

-- End of script
