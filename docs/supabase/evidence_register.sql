-- docs/supabase/evidence_register.sql
-- Evidence register table for SOC 2 readiness tracking. Idempotent and safe to re-run.

create extension if not exists pgcrypto;

create table if not exists public.evidence_register (
  id uuid primary key default gen_random_uuid(),
  control text not null,
  evidence text not null,
  owner text not null,
  system text not null,
  frequency text not null,
  last_collected date null,
  link text null,
  created_at timestamptz not null default now()
);

alter table public.evidence_register enable row level security;

-- Read for all authenticated; writes typically via admin tooling
DO $$ BEGIN
  DROP POLICY IF EXISTS evidence_read_all ON public.evidence_register;
  CREATE POLICY evidence_read_all ON public.evidence_register
  FOR SELECT TO authenticated
  USING (true);
END $$;

-- Optional: restrict writes to corp_admin by JWT role (aligns with repo patterns)
create or replace function public.jwt_claim(claim text)
returns text stable language sql as $$ select coalesce(current_setting('request.jwt.claims', true)::json->>claim, '') $$;

DO $$ BEGIN
  DROP POLICY IF EXISTS evidence_write_admin ON public.evidence_register;
  CREATE POLICY evidence_write_admin ON public.evidence_register
  FOR ALL TO authenticated
  USING ((coalesce(current_setting('request.jwt.claims', true)::json->'app_roles','[]'::json) ? 'corp_admin'))
  WITH CHECK ((coalesce(current_setting('request.jwt.claims', true)::json->'app_roles','[]'::json) ? 'corp_admin'));
END $$;
