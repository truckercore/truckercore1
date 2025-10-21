-- docs/supabase/connectors.sql
-- Connector registry (POS, loyalty, fleet cards, IoT) and per-org enablement. Idempotent.

create extension if not exists pgcrypto;

create table if not exists public.connectors (
  key text primary key,
  category text not null check (category in ('pos','loyalty','fleet_card','iot')),
  name text not null,
  certification text not null default 'none' check (certification in ('certified','beta','none')),
  docs_url text not null,
  config_schema jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.org_connectors (
  org_id uuid not null,
  connector_key text not null references public.connectors(key) on delete cascade,
  status text not null default 'disabled' check (status in ('disabled','enabled')),
  settings jsonb not null default '{}'::jsonb,
  last_sync_at timestamptz null,
  primary key (org_id, connector_key)
);

alter table public.connectors enable row level security;
alter table public.org_connectors enable row level security;

create or replace function public.jwt_claim(claim text)
returns text stable language sql as $$ select coalesce(current_setting('request.jwt.claims', true)::json->>claim, '') $$;

create policy if not exists connectors_read_all on public.connectors
for select to authenticated using (true);

create policy if not exists org_connectors_rw on public.org_connectors
for all to authenticated
using (org_id::text = public.jwt_claim('app_org_id'))
with check (org_id::text = public.jwt_claim('app_org_id'));
