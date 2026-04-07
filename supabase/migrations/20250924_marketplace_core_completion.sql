-- 20250924_marketplace_core_completion.sql
-- Purpose: Fill remaining gaps for marketplace issue spec.
-- Adds metrics_events sink, fee_ledger base table (with imbalance view),
-- enriches webhook_outbox for retry/health, alert delivery 24h view,
-- and seeds a codes taxonomy table for standard codes.
-- All statements are idempotent and safe to re-run.

-- ========== 1) Metrics sink ==========
create table if not exists public.metrics_events (
  id uuid primary key default gen_random_uuid(),
  kind text not null,
  props jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_metrics_kind_time on public.metrics_events (kind, created_at desc);

-- ========== 2) Fee ledger base ==========
create table if not exists public.fee_ledger (
  id uuid primary key default gen_random_uuid(),
  load_id uuid not null references public.loads(id) on delete cascade,
  bid_id uuid null references public.bids(id) on delete set null,
  entry_at timestamptz not null default now(),
  debit_cents int not null default 0,
  credit_cents int not null default 0,
  currency text not null default 'USD',
  note text null
);
create index if not exists idx_fee_ledger_load on public.fee_ledger(load_id);

-- View: fee imbalance must be empty for healthy ledger
create or replace view public.v_fee_imbalances as
select load_id,
       sum(debit_cents - credit_cents) as net_cents,
       count(*) as entries
from public.fee_ledger
group by load_id
having sum(debit_cents - credit_cents) <> 0;

-- ========== 3) Webhook outbox enrichments ==========
-- Ensure webhook_outbox table exists (a prior migration may have created it)
create table if not exists public.webhook_outbox (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  topic text not null,
  payload jsonb not null,
  next_attempt_at timestamptz not null default now(),
  delivered_at timestamptz null,
  dead_letter boolean not null default false,
  attempts int not null default 0
);
-- If it exists with older shape, add missing columns non-destructively
alter table if exists public.webhook_outbox
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists topic text,
  add column if not exists dead_letter boolean not null default false,
  add column if not exists attempts int not null default 0;

-- Due index as per spec (efficient fetching of pending deliveries)
create index if not exists idx_webhook_due on public.webhook_outbox (dead_letter, next_attempt_at);

-- 24h delivery health view (due/delivered/dlq)
create or replace view public.v_alert_delivery_24h as
select
  count(*) filter (where delivered_at is null and dead_letter=false and next_attempt_at<=now()) as due,
  count(*) filter (where delivered_at is not null) as delivered,
  count(*) filter (where dead_letter) as dead_lettered
from public.webhook_outbox
where coalesce(created_at, now()) >= now() - interval '24 hours';

-- ========== 4) Codes taxonomy (standardized) ==========
create table if not exists public.event_codes (
  code text primary key,
  grp text not null,       -- marketplace|guardrails|ledger|webhooks|health|tests
  note text null,
  created_at timestamptz not null default now()
);

-- Seed codes (on conflict do nothing)
insert into public.event_codes(code, grp, note) values
  -- Marketplace core
  ('LOAD_POSTED','marketplace','Load posted'),
  ('LOAD_MATCHED','marketplace','Load matched'),
  ('BID_PLACED','marketplace','Bid placed'),
  ('BID_ACCEPTED','marketplace','Bid accepted'),
  ('BID_REJECTED','marketplace','Bid rejected'),
  -- Guardrails
  ('DOUBLE_WINNER_ATTEMPT','guardrails','Attempt to set multiple winners'),
  ('IDEMPOTENCY_REPLAY','guardrails','Detected idempotency replay'),
  ('SCOPE_DENIED','guardrails','API scope denied'),
  ('RATE_LIMITED','guardrails','Rate limit enforced'),
  -- Ledger
  ('FEE_POSTED','ledger','Fee entry posted'),
  ('FEE_ROLLBACK','ledger','Fee rollback executed'),
  ('FEE_IMBALANCE','ledger','Ledger imbalance detected'),
  -- Webhooks
  ('WEBHOOK_DUE','webhooks','Webhook due'),
  ('WEBHOOK_DELIVERED','webhooks','Webhook delivered'),
  ('WEBHOOK_DLQ','webhooks','Webhook dead-lettered'),
  ('WEBHOOK_RETRY','webhooks','Webhook retry scheduled'),
  -- Health
  ('MP_HEALTH_SNAPSHOT','health','Marketplace health snapshot'),
  ('MATCH_LATENCY_SAMPLE','health','Match latency sample'),
  -- Tests
  ('GL_INVARIANTS_OK','tests','Green-light invariants pass'),
  ('GL_INVARIANTS_FAIL','tests','Green-light invariants fail')
on conflict (code) do nothing;

-- Notes:
-- 1) Existing api_key_has_scope and api_rate_check implementations already satisfy the spec semantics.
-- 2) Existing v_marketplace_health_24h and match_load function are preserved and compatible.
