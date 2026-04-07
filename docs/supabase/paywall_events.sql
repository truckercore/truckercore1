-- docs/supabase/paywall_events.sql
-- Paywall events logging for monetization UX. Idempotent and safe to re-run.

create extension if not exists pgcrypto;

create table if not exists public.paywall_events (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  feature text not null,
  event text not null check (event in ('view','click','upgrade')),
  source text not null,        -- e.g., 'sso_page','exec_dashboard'
  created_at timestamptz not null default now()
);

alter table public.paywall_events enable row level security;

-- JWT helper
create or replace function public.jwt_claim(claim text)
returns text stable language sql as $$ select coalesce(current_setting('request.jwt.claims', true)::json->>claim, '') $$;

create policy if not exists paywall_read_org on public.paywall_events
for select to authenticated using (org_id::text = public.jwt_claim('app_org_id'));

create policy if not exists paywall_write_org on public.paywall_events
for insert to authenticated with check (org_id::text = public.jwt_claim('app_org_id'));
