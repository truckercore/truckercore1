-- 20250924_hos_eld_foundation.sql
-- Foundations for HOS/ELD integrations: providers, tokens, normalized duty status & violations,
-- sync logging, and stale-data alert helper views. Idempotent.

create table if not exists public.hos_providers (
  key text primary key,                 -- e.g., 'samsara', 'motive', 'geo_tab'
  name text not null,
  meta jsonb not null default '{}'::jsonb
);

create table if not exists public.hos_provider_tokens (
  id uuid primary key default gen_random_uuid(),
  org_id uuid null,
  driver_id uuid null,
  provider_key text not null references public.hos_providers(key) on delete cascade,
  access_token text not null,
  refresh_token text null,
  expires_at timestamptz null,
  scope text[] null,
  last_success_at timestamptz null,
  last_error text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_hos_tokens_provider on public.hos_provider_tokens(provider_key);
create index if not exists idx_hos_tokens_org on public.hos_provider_tokens(org_id);

-- Normalized duty status samples (per driver, timeline)
create table if not exists public.hos_duty_status (
  id bigserial primary key,
  provider_key text not null,
  driver_id uuid not null,
  started_at timestamptz not null,
  ended_at timestamptz null,
  status text not null, -- off, sb, on, dr
  location jsonb null,
  meta jsonb not null default '{}'::jsonb
);
create index if not exists idx_hos_duty_driver_time on public.hos_duty_status(driver_id, started_at desc);

-- Normalized violations
create table if not exists public.hos_violations (
  id bigserial primary key,
  provider_key text not null,
  driver_id uuid not null,
  occurred_at timestamptz not null,
  kind text not null,  -- e.g., '11h_drive', '14h_on_duty', '30m_break', '70h_8d'
  severity text null,  -- minor|moderate|major|unknown
  meta jsonb not null default '{}'::jsonb
);
create index if not exists idx_hos_violations_driver_time on public.hos_violations(driver_id, occurred_at desc);

-- Sync log
create table if not exists public.hos_sync_log (
  id uuid primary key default gen_random_uuid(),
  provider_key text not null,
  token_id uuid null references public.hos_provider_tokens(id) on delete set null,
  ok boolean not null default true,
  rows_duty int not null default 0,
  rows_viol int not null default 0,
  duration_ms int not null default 0,
  ran_at timestamptz not null default now(),
  meta jsonb not null default '{}'::jsonb
);
create index if not exists idx_hos_sync_log_provider_time on public.hos_sync_log(provider_key, ran_at desc);

-- Helper view: tokens stale (never succeeded or success > 24h ago)
create or replace view public.v_hos_stale_tokens as
select t.*, coalesce(t.last_success_at, t.created_at) as last_good
from public.hos_provider_tokens t
where coalesce(t.last_success_at, t.created_at) < now() - interval '24 hours';

-- Helper view: drivers with no new duty status in 24h
create or replace view public.v_hos_data_stale as
select ds.driver_id, max(ds.started_at) as last_seen
from public.hos_duty_status ds
group by ds.driver_id
having max(ds.started_at) < now() - interval '24 hours';
