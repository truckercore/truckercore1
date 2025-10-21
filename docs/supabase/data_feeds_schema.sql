-- Data Feeds Schema (v1)
-- Location: docs/supabase/data_feeds_schema.sql

-- Sources catalog
create table if not exists public.data_feed_sources (
  id uuid primary key default gen_random_uuid(),
  feed text not null check (feed in ('telemetry','facility_dwell','broker_behavior')),
  source text not null,
  description text,
  created_at timestamptz not null default now(),
  unique(feed, source)
);

-- Anomalies
create table if not exists public.data_anomalies (
  id bigserial primary key,
  feed text not null,
  org_id uuid,
  code text not null,
  details jsonb,
  ingest_id uuid,
  created_at timestamptz not null default now()
);
create index if not exists idx_anom_feed_time on public.data_anomalies(feed, created_at desc);

-- Telemetry events (P0)
create table if not exists public.telemetry_events (
  event_id text primary key,
  org_id uuid not null,
  driver_user_id uuid,
  vehicle_id uuid,
  lat double precision,
  lon double precision,
  speed_mph double precision,
  activity text, -- driving, idling, off
  event_at timestamptz not null,
  received_at timestamptz not null default now(),
  ingest_id uuid,
  source text not null,
  meta jsonb
);
create index if not exists idx_telem_org_time on public.telemetry_events(org_id, event_at desc);
create index if not exists idx_telem_vehicle_time on public.telemetry_events(vehicle_id, event_at desc);

-- Facility dwell enter/exit events
create table if not exists public.facility_dwell_events (
  event_id text primary key,
  org_id uuid not null,
  vehicle_id uuid,
  facility_id text not null,
  action text not null check (action in ('enter','exit')),
  event_at timestamptz not null,
  received_at timestamptz not null default now(),
  lat double precision,
  lon double precision,
  ingest_id uuid,
  source text not null,
  meta jsonb
);
create index if not exists idx_dwell_org_fac_time on public.facility_dwell_events(org_id, facility_id, event_at desc);

-- Optional materialized dwell durations per visit (built offline)
create table if not exists public.facility_dwells (
  id bigserial primary key,
  org_id uuid not null,
  vehicle_id uuid,
  facility_id text not null,
  enter_at timestamptz not null,
  exit_at timestamptz,
  dwell_seconds integer,
  ingest_id uuid,
  source text,
  meta jsonb
);
create index if not exists idx_dwells_org_fac_enter on public.facility_dwells(org_id, facility_id, enter_at desc);

-- Broker behavior
create table if not exists public.broker_behavior_events (
  event_id text primary key, -- idempotency key
  org_id uuid not null,
  broker_id text not null,
  event_at timestamptz not null,
  metric text not null, -- bid, payment_term, on_time_pay, fall_off
  value numeric,
  unit text,
  received_at timestamptz not null default now(),
  ingest_id uuid,
  source text not null,
  meta jsonb
);
create index if not exists idx_broker_org_broker_time on public.broker_behavior_events(org_id, broker_id, event_at desc);

-- Simple ingest queue (at-least-once) — optional worker
create table if not exists public.ingest_queue (
  id bigserial primary key,
  task jsonb not null, -- {type, payload}
  status text not null default 'pending' check (status in ('pending','processing','done','error')),
  attempts integer not null default 0,
  next_retry_at timestamptz not null default now(),
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_queue_ready on public.ingest_queue(status, next_retry_at);

-- Assistant feedback
create table if not exists public.assistant_feedback (
  id bigserial primary key,
  org_id uuid not null,
  user_id uuid,
  context_id text not null,
  component text,
  rationale text,
  thumbs text not null check (thumbs in ('up','down')),
  comment text,
  meta jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_feedback_org_time on public.assistant_feedback(org_id, created_at desc);

-- Health view per feed
create or replace view public.data_feed_health as
select 'telemetry'::text as feed,
       count(*) filter (where received_at > now() - interval '1 hour') as last_hour_count,
       max(event_at) as latest_event_at,
       max(received_at) as latest_received_at
from public.telemetry_events
union all
select 'facility_dwell',
       count(*) filter (where received_at > now() - interval '1 hour'),
       max(event_at),
       max(received_at)
from public.facility_dwell_events
union all
select 'broker_behavior',
       count(*) filter (where received_at > now() - interval '1 hour'),
       max(event_at),
       max(received_at)
from public.broker_behavior_events;

-- RLS placeholders (enable and restrict by org_id — implement per project policy)
-- alter table public.telemetry_events enable row level security;
-- create policy telem_org_select on public.telemetry_events for select using (auth.uid() is not null);
