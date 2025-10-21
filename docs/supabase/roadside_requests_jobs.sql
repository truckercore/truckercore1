-- docs/supabase/roadside_requests_jobs.sql
-- Roadside Requests/Jobs schema (row-level) and updated_at triggers. Idempotent and safe to re-run.

create extension if not exists pgcrypto;

-- Tables
create table if not exists public.roadside_requests (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  location_id uuid null,
  service_type text not null,
  status text not null default 'open' check (status in ('open','assigned','enroute','done','canceled')),
  details jsonb not null default '{}'::jsonb,
  requested_by uuid not null,
  assigned_provider_id uuid null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.roadside_jobs (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  request_id uuid not null references public.roadside_requests(id) on delete cascade,
  provider_id uuid not null,
  status text not null default 'assigned' check (status in ('assigned','enroute','on_site','completed','failed')),
  eta_minutes int null,
  notes text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- RLS: desktop (org-scoped) can read changes; writes via Edge/service role
alter table public.roadside_requests enable row level security;
alter table public.roadside_jobs enable row level security;

-- Helper: read jwt claim (shared pattern in repo)
create or replace function public.jwt_claim(claim text)
returns text stable language sql as $$ select coalesce(current_setting('request.jwt.claims', true)::json->>claim, '') $$;

-- Read policies (org scoped)
DO $$ BEGIN
  DROP POLICY IF EXISTS rr_select_org ON public.roadside_requests;
  CREATE POLICY rr_select_org ON public.roadside_requests
  FOR SELECT TO authenticated
  USING (org_id::text = public.jwt_claim('app_org_id'));
END $$;

DO $$ BEGIN
  DROP POLICY IF EXISTS rj_select_org ON public.roadside_jobs;
  CREATE POLICY rj_select_org ON public.roadside_jobs
  FOR SELECT TO authenticated
  USING (org_id::text = public.jwt_claim('app_org_id'));
END $$;

-- Triggers (touch updated_at)
create or replace function public.touch_updated_at() returns trigger
language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='roadside_requests') THEN
    DROP TRIGGER IF EXISTS trg_rr_touch ON public.roadside_requests;
    CREATE TRIGGER trg_rr_touch BEFORE UPDATE ON public.roadside_requests
    FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='roadside_jobs') THEN
    DROP TRIGGER IF EXISTS trg_rj_touch ON public.roadside_jobs;
    CREATE TRIGGER trg_rj_touch BEFORE UPDATE ON public.roadside_jobs
    FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();
  END IF;
END $$;
