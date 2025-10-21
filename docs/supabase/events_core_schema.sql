-- docs/supabase/events_core_schema.sql
-- Core Events, Aggregates, Trust, and RLS for TruckerCore
-- Safe to re-run (IF NOT EXISTS / DO blocks). Requires pgcrypto and earthdistance (for ll_to_earth) or PostGIS optional.

create extension if not exists pgcrypto;
create extension if not exists cube; -- for earthdistance
create extension if not exists earthdistance;

-- 1) Raw GPS (short retention; no public read)
create table if not exists public.gps_samples (
  id bigserial primary key,
  user_id uuid not null,
  org_id uuid null,
  lat double precision not null,
  lng double precision not null,
  speed_kph double precision null,
  heading_deg double precision null,
  accuracy_m double precision null,
  source text not null default 'mobile' check (source in ('mobile','sdk')),
  ts timestamptz not null default now()
);
create index if not exists idx_gps_samples_ts_desc on public.gps_samples (ts desc);
-- If earthdistance is available, keep a geo index; ignore errors if not available
DO $$ BEGIN
  EXECUTE 'create index if not exists idx_gps_samples_earth on public.gps_samples using gist (ll_to_earth(lat, lng))';
EXCEPTION WHEN undefined_function THEN
  -- skip if ll_to_earth is unavailable
  NULL;
END $$;

-- 2) POI reports
create table if not exists public.poi_reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  poi_id uuid not null,
  kind text not null check (kind in ('parking','weigh','incident','fuel')),
  status text null,              -- e.g., 'open','some','full','closed','bypass'
  payload jsonb null,            -- extra fields (price, severity, notes)
  photo_url text null,
  trust_snapshot numeric(4,3) not null default 0.5,
  lat double precision null,
  lng double precision null,
  ts timestamptz not null default now()
);
create index if not exists idx_poi_reports_poi_ts on public.poi_reports (poi_id, ts desc);

-- 3) Votes
create table if not exists public.poi_report_votes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  report_id uuid not null references public.poi_reports(id) on delete cascade,
  vote smallint not null check (vote in (-1, 1)),
  ts timestamptz not null default now(),
  unique (user_id, report_id)
);

-- 4) Aggregated states
create table if not exists public.parking_state (
  poi_id uuid primary key,
  occupancy text not null check (occupancy in ('open','some','full','unknown')),
  confidence numeric(4,3) not null default 0.5,
  last_update timestamptz not null default now(),
  source_mix jsonb not null default '{}'::jsonb
);
create table if not exists public.weigh_station_state (
  poi_id uuid primary key,
  status text not null check (status in ('open','closed','bypass','unknown')),
  confidence numeric(4,3) not null default 0.5,
  last_update timestamptz not null default now(),
  source_mix jsonb not null default '{}'::jsonb
);

-- 5) Trust
create table if not exists public.user_trust (
  user_id uuid primary key,
  score numeric(4,3) not null default 0.5,
  last_calc timestamptz not null default now(),
  features jsonb not null default '{}'::jsonb
);

-- 6) RLS Policies
alter table public.gps_samples enable row level security;
DO $$ BEGIN
  DROP POLICY IF EXISTS gps_insert_self ON public.gps_samples;
  CREATE POLICY gps_insert_self ON public.gps_samples
  FOR INSERT TO authenticated
  WITH CHECK (user_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'sub',''));
END $$;
-- No select for clients (omit select policy)

alter table public.poi_reports enable row level security;
DO $$ BEGIN
  DROP POLICY IF EXISTS poi_reports_insert_self ON public.poi_reports;
  CREATE POLICY poi_reports_insert_self ON public.poi_reports
  FOR INSERT TO authenticated
  WITH CHECK (user_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'sub',''));
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS poi_reports_read_all ON public.poi_reports;
  CREATE POLICY poi_reports_read_all ON public.poi_reports
  FOR SELECT TO authenticated
  USING (true);
END $$;
-- Optional: allow update/delete own within short window (10 minutes)
DO $$ BEGIN
  DROP POLICY IF EXISTS poi_reports_update_self_window ON public.poi_reports;
  CREATE POLICY poi_reports_update_self_window ON public.poi_reports
  FOR UPDATE TO authenticated
  USING (
    user_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'sub','')
    AND ts > now() - interval '10 minutes'
  )
  WITH CHECK (
    user_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'sub','')
  );
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS poi_reports_delete_self_window ON public.poi_reports;
  CREATE POLICY poi_reports_delete_self_window ON public.poi_reports
  FOR DELETE TO authenticated
  USING (
    user_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'sub','')
    AND ts > now() - interval '10 minutes'
  );
END $$;

alter table public.poi_report_votes enable row level security;
DO $$ BEGIN
  DROP POLICY IF EXISTS votes_insert_self ON public.poi_report_votes;
  CREATE POLICY votes_insert_self ON public.poi_report_votes
  FOR INSERT TO authenticated
  WITH CHECK (user_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'sub',''));
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS votes_read_all ON public.poi_report_votes;
  CREATE POLICY votes_read_all ON public.poi_report_votes
  FOR SELECT TO authenticated
  USING (true);
END $$;

alter table public.parking_state enable row level security;
DO $$ BEGIN
  DROP POLICY IF EXISTS parking_state_read_all ON public.parking_state;
  CREATE POLICY parking_state_read_all ON public.parking_state
  FOR SELECT TO authenticated
  USING (true);
END $$;

alter table public.weigh_station_state enable row level security;
DO $$ BEGIN
  DROP POLICY IF EXISTS weigh_state_read_all ON public.weigh_station_state;
  CREATE POLICY weigh_state_read_all ON public.weigh_station_state
  FOR SELECT TO authenticated
  USING (true);
END $$;

-- 7) Helpful indexes for aggregates
create index if not exists idx_pr_kind_ts on public.poi_reports(kind, ts desc);
create index if not exists idx_pr_user_ts on public.poi_reports(user_id, ts desc);
create index if not exists idx_votes_report on public.poi_report_votes(report_id);

-- 8) Retention guidance (set up via cron jobs, not enforced here)
-- Suggestion: DELETE FROM public.gps_samples WHERE ts < now() - interval '30 days';
-- Suggestion: DELETE FROM public.poi_reports WHERE ts < now() - interval '180 days' AND trust_snapshot < 0.3;
