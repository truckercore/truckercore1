-- Phase 2 — Market Intelligence & Profit Tools (SQL Migrations)
-- This file creates tables and indexes for:
--  - market_rates
--  - trihaul_suggestions
--  - broker_credit_scores (and optional credit_sources)
-- Includes RLS guidance. Safe to run multiple times with IF NOT EXISTS guards.

create extension if not exists "uuid-ossp";

-- 1) market_rates (public dataset + org-private rows)
create table if not exists public.market_rates (
  id uuid primary key default uuid_generate_v4(),
  org_id uuid null, -- null => public dataset row
  origin_geo jsonb not null, -- {city,state,zip,lat,lng}
  dest_geo jsonb not null,   -- {city,state,zip,lat,lng}
  lane_key text not null,    -- normalized origin_zip->dest_zip
  spot_rate_usd_per_mi numeric(8,4) not null,
  contract_rate_usd_per_mi numeric(8,4) not null,
  sample_size int not null default 0,
  collected_at timestamptz not null,
  source text not null check (source in ('tc_agg','partner_api','manual_upload'))
);
create index if not exists idx_market_rates_lane_time on public.market_rates (lane_key, collected_at desc);
create index if not exists idx_market_rates_source_tc on public.market_rates (source) where source = 'tc_agg';

alter table public.market_rates enable row level security;
-- RLS: public rows (org_id is null) readable by all auth users; tenant rows only visible to that org
-- Example policies (adapt claims names to your JWT hook):
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='market_rates' AND policyname='market_rates_select') THEN
    CREATE POLICY market_rates_select ON public.market_rates
      FOR SELECT USING (
        org_id is null OR ((current_setting('request.jwt.claims', true)::jsonb ->> 'app_org_id')::uuid = org_id)
      );
  END IF;
END $$;

-- 2) trihaul_suggestions
create table if not exists public.trihaul_suggestions (
  id uuid primary key default uuid_generate_v4(),
  org_id uuid not null,
  request_context jsonb not null, -- {origin,dest,date,equipment,constraints}
  itinerary jsonb not null,       -- {legs:[{o,m,d,mi,est_rate_ppm},...]} or O->M->D->O
  est_miles_total numeric(8,1) not null,
  est_revenue_total numeric(12,2) not null,
  est_ppm numeric(6,3) not null,
  generated_at timestamptz not null default now(),
  accepted boolean not null default false,
  notes text null
);
create index if not exists idx_trihaul_org_time on public.trihaul_suggestions (org_id, generated_at desc);

alter table public.trihaul_suggestions enable row level security;
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='trihaul_suggestions' AND policyname='trihaul_select') THEN
    CREATE POLICY trihaul_select ON public.trihaul_suggestions
      FOR SELECT USING (((current_setting('request.jwt.claims', true)::jsonb ->> 'app_org_id')::uuid = org_id));
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='trihaul_suggestions' AND policyname='trihaul_update') THEN
    CREATE POLICY trihaul_update ON public.trihaul_suggestions
      FOR UPDATE USING (((current_setting('request.jwt.claims', true)::jsonb ->> 'app_org_id')::uuid = org_id))
      WITH CHECK (((current_setting('request.jwt.claims', true)::jsonb ->> 'app_org_id')::uuid = org_id));
  END IF;
END $$;

-- 3) broker_credit_scores
create table if not exists public.broker_credit_scores (
  broker_id uuid primary key,
  score int not null check (score between 0 and 100),
  days_to_pay_avg int not null,
  disputes_90d int not null default 0,
  last_updated_at timestamptz not null default now()
);
-- Optional provenance table
create table if not exists public.credit_sources (
  id uuid primary key default uuid_generate_v4(),
  broker_id uuid not null,
  source text not null,
  payload jsonb,
  collected_at timestamptz not null default now()
);
create index if not exists idx_credit_sources_broker_time on public.credit_sources (broker_id, collected_at desc);

alter table public.broker_credit_scores enable row level security;
-- For simplicity, make credit scores readable by all authenticated users
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='broker_credit_scores' AND policyname='credit_scores_select') THEN
    CREATE POLICY credit_scores_select ON public.broker_credit_scores
      FOR SELECT USING (true);
  END IF;
END $$;

-- Edge Functions (docs)
-- rates_refresh_job: daily 02:30 local, aggregates org awarded rates into market_rates with source='tc_agg'
-- trihaul_suggest: on-demand suggestion engine using market_rates + current loads inventory
-- credit_refresh_job: daily CSV/partner sync into broker_credit_scores
