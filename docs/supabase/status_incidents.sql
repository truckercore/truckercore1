-- docs/supabase/status_incidents.sql
-- Public status incidents table and RLS. Idempotent.

create extension if not exists pgcrypto;

create table if not exists public.status_incidents (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  status text not null check (status in ('investigating','identified','monitoring','resolved')),
  impact text not null check (impact in ('none','minor','major','critical')),
  components text[] not null default '{}',
  started_at timestamptz not null default now(),
  resolved_at timestamptz null,
  updates jsonb not null default '[]'::jsonb,
  public boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists idx_status_incidents_time on public.status_incidents (started_at desc);

alter table public.status_incidents enable row level security;
DO $$ BEGIN
  DROP POLICY IF EXISTS status_incidents_public ON public.status_incidents;
  CREATE POLICY status_incidents_public ON public.status_incidents
  FOR SELECT TO anon, authenticated
  USING (public = true);
END $$;
