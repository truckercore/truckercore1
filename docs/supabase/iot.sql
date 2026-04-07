-- docs/supabase/iot.sql
-- IoT devices and events schema for parking sensors and shower boards.
-- Idempotent and safe to re-run.

create extension if not exists pgcrypto;

-- Devices registry (store token hash only; never store raw token)
create table if not exists public.iot_devices (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  poi_id uuid not null,
  kind text not null check (kind in ('parking_counter','shower_board')),
  token_hash text not null,
  meta jsonb not null default '{}'::jsonb,
  enabled boolean not null default true,
  created_at timestamptz not null default now()
);
create index if not exists idx_iot_devices_org_poi on public.iot_devices (org_id, poi_id);

-- Raw events (append-only)
create table if not exists public.iot_events (
  id bigserial primary key,
  device_id uuid not null,
  poi_id uuid not null,
  kind text not null check (kind in ('parking','shower')),
  payload jsonb not null,
  received_at timestamptz not null default now()
);
create index if not exists idx_iot_events_poi_time on public.iot_events (poi_id, received_at desc);

-- RLS guidance: allow org-scoped read if desired; writes via service role only.
alter table public.iot_devices enable row level security;
alter table public.iot_events enable row level security;

create or replace function public.jwt_claim(claim text)
returns text stable language sql as $$ select coalesce(current_setting('request.jwt.claims', true)::json->>claim, '') $$;

DO $$ BEGIN
  DROP POLICY IF EXISTS iot_devices_read_org ON public.iot_devices;
  CREATE POLICY iot_devices_read_org ON public.iot_devices
  FOR SELECT TO authenticated
  USING (org_id::text = public.jwt_claim('app_org_id'));
EXCEPTION WHEN undefined_table THEN NULL; END $$;

DO $$ BEGIN
  DROP POLICY IF EXISTS iot_events_read_org ON public.iot_events;
  CREATE POLICY iot_events_read_org ON public.iot_events
  FOR SELECT TO authenticated
  USING (exists(select 1 from public.iot_devices d where d.id = device_id and d.org_id::text = public.jwt_claim('app_org_id')));
EXCEPTION WHEN undefined_table THEN NULL; END $$;

-- Optional helpers: upsert into parking_state or a future services_state
-- For portability we keep this as guidance; production fusion logic may run separately.
-- Example fusion cue: a view mapping latest iot_events to a parking fill score could be added later.
