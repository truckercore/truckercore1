-- 20250924_event_taxonomy.sql
-- Purpose: Event taxonomy + durable metrics/events sink, fee ledger shape, webhook outbox,
-- and health/metrics views per spec. Written to be idempotent and backward-compatible
-- with existing schema in this repository.

-- 1) Event taxonomy -----------------------------------------------------------
create table if not exists public.event_codes (
  code text primary key,
  description text,
  severity text,
  domain text
);

-- Ensure required columns exist and constraints/defaults are aligned
alter table if exists public.event_codes
  add column if not exists description text,
  add column if not exists severity text,
  add column if not exists domain text;

-- Add severity check and default in a guarded way (cannot use IF NOT EXISTS on constraint)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'event_codes_severity_chk'
  ) THEN
    ALTER TABLE public.event_codes
      ADD CONSTRAINT event_codes_severity_chk
      CHECK (severity in ('info','warn','error','critical'));
  END IF;
END$$;

-- Backfill defaults from legacy columns if present (grp/note)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='event_codes' AND column_name='grp') THEN
    UPDATE public.event_codes SET domain = coalesce(domain, grp) WHERE domain IS NULL;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='event_codes' AND column_name='note') THEN
    UPDATE public.event_codes SET description = coalesce(description, note) WHERE description IS NULL;
  END IF;
  UPDATE public.event_codes SET severity = coalesce(severity, 'info') WHERE severity IS NULL;
END$$;

-- Minimal seed per spec
insert into public.event_codes (code, description, severity, domain) values
  ('load.posted','Load posted to marketplace','info','marketplace'),
  ('bid.placed','Bid placed on load','info','marketplace'),
  ('load.matched','Carrier matched to load','info','marketplace'),
  ('promos.approve','Promo approved at POS','info','promos'),
  ('webhook.delivered','Webhook delivered','info','integrations'),
  ('webhook.dead_letter','Webhook moved to DLQ','error','integrations'),
  ('fee.debit','Fee debit ledger entry','info','billing'),
  ('fee.credit','Fee credit ledger entry','info','billing'),
  ('alert.raise','Alert raised','warn','ops'),
  ('remediation.click','Remediation link clicked','info','ops')
on conflict (code) do nothing;


-- 2) Metrics/events sink ------------------------------------------------------
-- Create table if missing; otherwise augment to match desired shape
create table if not exists public.metrics_events (
  id uuid primary key default gen_random_uuid(),
  at timestamptz not null default now(),
  org_id uuid null,
  user_id uuid null,
  event_code text not null,
  kind text null,
  props jsonb not null default '{}'::jsonb
);

-- Augment existing table columns
alter table if exists public.metrics_events
  add column if not exists at timestamptz not null default now(),
  add column if not exists org_id uuid,
  add column if not exists user_id uuid,
  add column if not exists event_code text,
  add column if not exists kind text,
  add column if not exists props jsonb not null default '{}'::jsonb;

-- Foreign key to event_codes(code) if not present
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE table_schema='public' AND table_name='metrics_events' AND constraint_type='FOREIGN KEY' AND constraint_name='metrics_events_event_code_fkey'
  ) THEN
    ALTER TABLE public.metrics_events
      ADD CONSTRAINT metrics_events_event_code_fkey
      FOREIGN KEY (event_code) REFERENCES public.event_codes(code);
  END IF;
END$$;

create index if not exists idx_metrics_org_time on public.metrics_events (org_id, at desc);
create index if not exists idx_metrics_code_time on public.metrics_events (event_code, at desc);

-- RLS: org-scoped read
alter table public.metrics_events enable row level security;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='metrics_events' AND policyname='metrics_read_org'
  ) THEN
    EXECUTE $$create policy metrics_read_org on public.metrics_events
             for select to authenticated
             using (coalesce(org_id::text,'') = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));$$;
  END IF;
END$$;


-- 3) Fee ledger (double-entry) -----------------------------------------------
-- Augment/create table to support desired columns while preserving legacy ones
create table if not exists public.fee_ledger (
  id uuid primary key default gen_random_uuid(),
  at timestamptz not null default now(),
  org_id uuid not null,
  ref_type text not null,
  ref_id uuid not null,
  account text not null,
  delta_cents integer not null,
  currency text not null default 'USD',
  note text null
);
-- Add missing columns in existing deployments
alter table if exists public.fee_ledger
  add column if not exists at timestamptz not null default now(),
  add column if not exists org_id uuid,
  add column if not exists ref_type text,
  add column if not exists ref_id uuid,
  add column if not exists account text,
  add column if not exists delta_cents integer,
  add column if not exists currency text not null default 'USD',
  add column if not exists note text;

create index if not exists idx_fee_ledger_ref on public.fee_ledger (ref_type, ref_id);
create index if not exists idx_fee_ledger_org_time on public.fee_ledger (org_id, at desc);

alter table public.fee_ledger enable row level security;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='fee_ledger' AND policyname='fee_ledger_read_org'
  ) THEN
    EXECUTE $$create policy fee_ledger_read_org on public.fee_ledger
             for select to authenticated
             using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));$$;
  END IF;
END$$;

-- View: Ledger imbalances per ref (supports legacy debit/credit as fallback)
create or replace view public.v_fee_imbalances as
select
  coalesce(fl.ref_type, 'load') as ref_type,
  coalesce(fl.ref_id, fl.load_id) as ref_id,
  sum(coalesce(fl.delta_cents, (fl.debit_cents - fl.credit_cents))) as net_cents,
  count(*) as entries
from public.fee_ledger fl
group by 1,2
having sum(coalesce(fl.delta_cents, (fl.debit_cents - fl.credit_cents))) <> 0;


-- 4) Webhook outbox -----------------------------------------------------------
create table if not exists public.webhook_outbox (
  id uuid primary key default gen_random_uuid(),
  org_id uuid null,
  event_type text not null,
  payload jsonb not null,
  created_at timestamptz not null default now(),
  next_attempt_at timestamptz not null default now(),
  attempts int not null default 0,
  delivered_at timestamptz null,
  dead_letter boolean not null default false,
  headers jsonb not null default '{}'::jsonb
);

-- Add missing columns if an older shape exists
alter table if exists public.webhook_outbox
  add column if not exists org_id uuid,
  add column if not exists event_type text,
  add column if not exists payload jsonb,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists next_attempt_at timestamptz not null default now(),
  add column if not exists attempts int not null default 0,
  add column if not exists delivered_at timestamptz,
  add column if not exists dead_letter boolean not null default false,
  add column if not exists headers jsonb not null default '{}'::jsonb;

create index if not exists idx_outbox_next on public.webhook_outbox (dead_letter, next_attempt_at);
create index if not exists idx_outbox_org_time on public.webhook_outbox (org_id, created_at desc);

alter table public.webhook_outbox enable row level security;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='webhook_outbox' AND policyname='outbox_read_org'
  ) THEN
    EXECUTE $$create policy outbox_read_org on public.webhook_outbox
             for select to authenticated
             using (coalesce(org_id::text,'') = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));$$;
  END IF;
END$$;


-- 5) Health/metrics views -----------------------------------------------------
-- Webhook delivery failures (last 24h) by org/event type
create or replace view public.v_alert_delivery_failures_24h as
select
  coalesce(org_id, '00000000-0000-0000-0000-000000000000'::uuid) as org_id,
  event_type,
  count(*) as failures_24h
from public.webhook_outbox
where dead_letter = true
  and created_at >= now() - interval '24 hours'
group by 1,2
order by failures_24h desc;

-- Marketplace health summary (last 24h) via metrics events
create or replace view public.v_marketplace_health_24h as
with base as (
  select event_code, at
  from public.metrics_events
  where at >= now() - interval '24 hours'
)
select
  (select count(*) from base where event_code = 'load.posted') as loads_posted,
  (select count(*) from base where event_code = 'bid.placed') as bids_placed,
  (select count(*) from base where event_code = 'load.matched') as loads_matched,
  (select round(100.0 * nullif((select count(*) from base where event_code = 'load.matched'),0)
          / nullif((select count(*) from base where event_code = 'load.posted'),0),2)) as match_rate_pct;

-- Metrics rollup: counts by event_code (last 24h)
create or replace view public.v_metrics_24h_rollup as
select event_code, count(*) as n
from public.metrics_events
where at >= now() - interval '24 hours'
group by event_code
order by n desc;

-- Done.
