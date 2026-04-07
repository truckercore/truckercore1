-- 20250928_007_integrations_core.sql
-- Idempotent Integrations Core schema

-- Prereqs
create extension if not exists pgcrypto;
create extension if not exists postgis;

-- Tenancy orgs (if not present)
create table if not exists public.orgs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  plan text not null default 'free',
  created_at timestamptz not null default now()
);

-- Integration providers catalog
create table if not exists public.integration_providers (
  key text primary key,
  title text not null,
  oauth_enabled boolean not null default true,
  webhook_enabled boolean not null default true
);

insert into public.integration_providers(key, title, oauth_enabled, webhook_enabled)
values
  ('samsara','Samsara', true, true),
  ('qbo','QuickBooks Online', true, true)
on conflict (key) do nothing;

-- Connection store (tokens/metadata) per org+provider
create table if not exists public.integration_connections (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id) on delete cascade,
  provider text not null references public.integration_providers(key),
  access_token text,
  refresh_token text,
  expires_at timestamptz,
  scope text,
  external_account_id text,
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (org_id, provider)
);

-- Webhook receipts (idempotent)
create table if not exists public.integration_webhooks (
  provider text not null references public.integration_providers(key),
  event_id text not null,
  received_at timestamptz not null default now(),
  signature_valid boolean not null default false,
  payload jsonb not null,
  processed boolean not null default false,
  error text,
  primary key (provider, event_id)
);

-- ETL job queue
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid=t.typnamespace
    WHERE n.nspname='public' AND t.typname='etl_status'
  ) THEN
    create type public.etl_status as enum ('queued','running','ok','err');
  END IF;
END $$;

create table if not exists public.etl_jobs (
  id uuid primary key default gen_random_uuid(),
  provider text not null references public.integration_providers(key),
  connection_id uuid references public.integration_connections(id) on delete set null,
  kind text not null,
  args jsonb not null default '{}'::jsonb,
  status public.etl_status not null default 'queued',
  started_at timestamptz,
  finished_at timestamptz,
  log text,
  created_at timestamptz not null default now()
);

-- Normalization targets (expand later)
create table if not exists public.normalized_telemetry (
  id bigint generated always as identity primary key,
  org_id uuid not null references public.orgs(id) on delete cascade,
  source_provider text not null,
  device_id text,
  ts timestamptz not null,
  lat double precision not null,
  lng double precision not null,
  speed_kph double precision,
  meta jsonb not null default '{}'::jsonb
);
create index if not exists idx_norm_tel_org_ts on public.normalized_telemetry(org_id, ts desc);

create table if not exists public.normalized_invoices (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id) on delete cascade,
  source_provider text not null,
  external_id text not null,
  amount_cents bigint not null,
  currency text not null default 'USD',
  status text not null,
  issued_at timestamptz,
  meta jsonb not null default '{}'::jsonb,
  unique (org_id, source_provider, external_id)
);

-- Auth helper view for org
create or replace view public.v_me as
select u.id as user_id, (u.raw_user_meta_data->>'org_id')::uuid as org_id
from auth.users u
where u.id = auth.uid();

-- RLS enable
alter table public.integration_connections enable row level security;
alter table public.integration_webhooks    enable row level security;
alter table public.etl_jobs                enable row level security;
alter table public.normalized_telemetry    enable row level security;
alter table public.normalized_invoices     enable row level security;

-- RLS policies
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='integration_connections' AND policyname='conn_tenant'
  ) THEN
    create policy conn_tenant on public.integration_connections
      for all
      using (org_id = (select org_id from public.v_me))
      with check (org_id = (select org_id from public.v_me));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='integration_webhooks' AND policyname='wh_read'
  ) THEN
    create policy wh_read on public.integration_webhooks
      for select using (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='integration_webhooks' AND policyname='wh_write_service_only'
  ) THEN
    create policy wh_write_service_only on public.integration_webhooks
      for all to service_role using (true) with check (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='etl_jobs' AND policyname='etl_read'
  ) THEN
    create policy etl_read on public.etl_jobs
      for select using (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='etl_jobs' AND policyname='etl_write_service_only'
  ) THEN
    create policy etl_write_service_only on public.etl_jobs
      for all to service_role using (true) with check (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='normalized_telemetry' AND policyname='tel_tenant'
  ) THEN
    create policy tel_tenant on public.normalized_telemetry
      using (org_id = (select org_id from public.v_me))
      with check (org_id = (select org_id from public.v_me));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='normalized_invoices' AND policyname='inv_tenant'
  ) THEN
    create policy inv_tenant on public.normalized_invoices
      using (org_id = (select org_id from public.v_me))
      with check (org_id = (select org_id from public.v_me));
  END IF;
END $$;

-- Integration status for UI
create or replace function public.integration_status_for_org(p_org uuid)
returns table(provider text, connected boolean, external_account_id text)
language sql stable as $$
  select ip.key, (ic.id is not null) as connected, coalesce(ic.external_account_id,'') as external_account_id
  from public.integration_providers ip
  left join public.integration_connections ic
    on ic.provider = ip.key and ic.org_id = p_org
  order by ip.key;
$$;

grant execute on function public.integration_status_for_org(uuid) to anon, authenticated, service_role;
