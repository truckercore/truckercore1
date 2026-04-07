-- 20250924_event_codes_canonical.sql
-- Purpose: Canonical event code catalog and metrics plumbing per spec.
-- Adds/augments event_codes, metrics_events, fee_ledger, webhook_outbox,
-- health/rollup views, RLS, and seeds canonical codes. Idempotent and safe to re-run.

-- ========== 1) Event code catalog ==========
create table if not exists public.event_codes (
  code text primary key,
  category text not null,
  description text not null,
  severity text null check (severity in ('info','warning','critical')),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

-- If an older shape exists (e.g., columns domain/grp/note), add missing columns non-destructively
alter table if exists public.event_codes
  add column if not exists category text,
  add column if not exists description text,
  add column if not exists severity text,
  add column if not exists active boolean not null default true,
  add column if not exists created_at timestamptz not null default now();

-- Backfill category/description from legacy columns if present
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='event_codes' AND column_name='grp'
  ) THEN
    -- Prefer existing category, else copy grp/domain into category
    EXECUTE $$update public.event_codes set category = coalesce(category, grp) where category is null;$$;
  END IF;
  IF EXISTS (
    SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='event_codes' AND column_name='domain'
  ) THEN
    EXECUTE $$update public.event_codes set category = coalesce(category, domain) where category is null;$$;
  END IF;
  IF EXISTS (
    SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='event_codes' AND column_name='note'
  ) THEN
    EXECUTE $$update public.event_codes set description = coalesce(description, note) where description is null;$$;
  END IF;
END $$;

create index if not exists idx_event_codes_category on public.event_codes(category);

-- RLS (read-only to authenticated)
alter table public.event_codes enable row level security;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='event_codes' AND policyname='event_codes_read_all'
  ) THEN
    CREATE POLICY event_codes_read_all ON public.event_codes FOR SELECT TO authenticated USING (true);
  END IF;
END $$;

-- ========== 2) Metrics events (append-only) ==========
create table if not exists public.metrics_events (
  id bigserial primary key,
  at timestamptz not null default now(),
  org_id uuid null,
  event_code text not null,
  actor_user_id uuid null,
  ref_id text null,
  kv jsonb not null default '{}'::jsonb
);

-- If table already exists with different shape, add the missing columns
alter table if exists public.metrics_events
  add column if not exists at timestamptz not null default now(),
  add column if not exists org_id uuid,
  add column if not exists event_code text,
  add column if not exists actor_user_id uuid,
  add column if not exists ref_id text,
  add column if not exists kv jsonb not null default '{}'::jsonb;

-- Hygiene: FK to event_codes(code)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE table_schema='public' AND table_name='metrics_events' AND constraint_type='FOREIGN KEY' AND constraint_name='metrics_events_code_fk'
  ) THEN
    ALTER TABLE public.metrics_events
      ADD CONSTRAINT metrics_events_code_fk FOREIGN KEY (event_code)
      REFERENCES public.event_codes(code) ON UPDATE CASCADE;
  END IF;
END $$;

create index if not exists idx_metrics_events_at on public.metrics_events(at desc);
create index if not exists idx_metrics_events_code_at on public.metrics_events(event_code, at desc);
create index if not exists idx_metrics_events_org_at on public.metrics_events(org_id, at desc);

-- RLS (read-only to authenticated; org-scoped or null)
alter table public.metrics_events enable row level security;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='metrics_events' AND policyname='metrics_events_read_org'
  ) THEN
    CREATE POLICY metrics_events_read_org ON public.metrics_events
    FOR SELECT TO authenticated
    USING (org_id IS NULL OR org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
  END IF;
END $$;

-- ========== 3) Fee ledger (double-entry minimal) ==========
create table if not exists public.fee_ledger (
  id bigserial primary key,
  at timestamptz not null default now(),
  org_id uuid not null,
  entry_type text not null check (entry_type in ('debit','credit')),
  account text not null,
  amount_cents int not null check (amount_cents > 0),
  reference text null,
  meta jsonb not null default '{}'::jsonb
);
create index if not exists idx_fee_ledger_org_at on public.fee_ledger(org_id, at desc);

alter table public.fee_ledger enable row level security;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='fee_ledger' AND policyname='fee_ledger_read_org'
  ) THEN
    CREATE POLICY fee_ledger_read_org ON public.fee_ledger
    FOR SELECT TO authenticated
    USING (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
  END IF;
END $$;

-- Fee imbalance view (must be empty when balanced)
create or replace view public.v_fee_imbalances as
with sums as (
  select org_id, account,
         sum(case when entry_type='debit' then amount_cents else 0 end) as debits,
         sum(case when entry_type='credit' then amount_cents else 0 end) as credits
  from public.fee_ledger
  group by 1,2
),
imb as (
  select org_id,
         sum(debits - credits) as net_cents
  from sums
  group by 1
)
select * from imb where net_cents <> 0;

-- ========== 4) Webhook outbox (transactional outbox) ==========
create table if not exists public.webhook_outbox (
  id bigserial primary key,
  org_id uuid not null,
  event_type text not null,
  payload jsonb not null,
  created_at timestamptz not null default now(),
  delivered_at timestamptz null,
  dead_letter boolean not null default false,
  last_error text null,
  attempts int not null default 0,
  signature text null
);
create index if not exists idx_webhook_outbox_org_time on public.webhook_outbox(org_id, created_at desc);

alter table public.webhook_outbox enable row level security;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='webhook_outbox' AND policyname='webhook_outbox_read_org'
  ) THEN
    CREATE POLICY webhook_outbox_read_org ON public.webhook_outbox
    FOR SELECT TO authenticated
    USING (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
  END IF;
END $$;

-- ========== 5) Metrics views (health and rollups) ==========
-- Marketplace health (24h)
create or replace view public.v_marketplace_health_24h as
select
  coalesce(m.org_id, w.org_id) as org_id,
  count(*) filter (where m.event_code like 'marketplace.listing_%') as listings_events,
  count(*) filter (where m.event_code like 'marketplace.order_%') as order_events,
  count(*) filter (where w.delivered_at is null and w.dead_letter=false) as webhooks_pending,
  count(*) filter (where w.dead_letter) as webhooks_dlq
from public.metrics_events m
full outer join public.webhook_outbox w
  on w.org_id = m.org_id and w.created_at >= now() - interval '24 hours'
where m.at >= now() - interval '24 hours'
group by 1;

-- Event volume by code (24h)
create or replace view public.v_event_volume_24h as
select event_code, count(*) as n
from public.metrics_events
where at >= now() - interval '24 hours'
group by 1
order by n desc;

-- SSO failure rate by org (24h)
create or replace view public.v_sso_failure_rate_24h as
with a as (
  select org_id,
         count(*) filter (where event_code='sso.login_success') as ok,
         count(*) filter (where event_code='sso.login_failure') as ko
  from public.metrics_events
  where at >= now() - interval '24 hours'
  group by org_id
)
select org_id, (ok+ko) as attempts_24h, ko as failures_24h,
       case when (ok+ko)=0 then 0 else (ko::numeric/(ok+ko)) end as failure_rate_24h
from a;

-- ========== 6) Seed canonical event codes ==========
insert into public.event_codes (code, category, description, severity)
values
  ('system.startup','system','service/process start','info'),
  ('billing.fee_applied','billing','fee applied to ledger','info'),
  ('billing.fee_reversed','billing','fee reversal','warning'),
  ('webhook.enqueued','webhook','webhook enqueued','info'),
  ('webhook.delivered','webhook','webhook delivered','info'),
  ('webhook.failed','webhook','webhook delivery failed','warning'),
  ('webhook.retry','webhook','webhook retry scheduled','info'),
  ('marketplace.listing_created','marketplace','listing created','info'),
  ('marketplace.listing_updated','marketplace','listing updated','info'),
  ('marketplace.listing_published','marketplace','listing published','info'),
  ('marketplace.order_created','marketplace','order created','info'),
  ('marketplace.order_fulfilled','marketplace','order fulfilled','info'),
  ('marketplace.order_canceled','marketplace','order canceled','warning'),
  ('sso.login_success','sso','SSO login success','info'),
  ('sso.login_failure','sso','SSO login failure','warning'),
  ('sso.selfcheck_success','sso','SSO self-check success','info'),
  ('sso.selfcheck_failure','sso','SSO self-check failure','warning'),
  ('sso.canary_failure','sso','OIDC canary failure','warning'),
  ('scim.run_started','scim','SCIM run started','info'),
  ('scim.run_success','scim','SCIM run success','info'),
  ('scim.run_partial','scim','SCIM run partial','warning'),
  ('scim.run_failed','scim','SCIM run failed','critical'),
  ('alerts.fired','alerts','Alert fired','warning'),
  ('alerts.delivered','alerts','Alert delivered','info'),
  ('alerts.snoozed','alerts','Alert snoozed','info'),
  ('alerts.escalation_logged','alerts','Escalation broke snooze','warning'),
  ('alerts.retested','alerts','Retest executed','info'),
  ('alerts.retest_failed','alerts','Retest failed','warning'),
  ('ops.rotation_due','ops','Secret rotation due','warning'),
  ('ops.rotation_done','ops','Secret rotation completed','info'),
  ('ops.backup_success','ops','Backup success','info'),
  ('ops.backup_failed','ops','Backup failed','critical')
on conflict (code) do nothing;

-- ========== 7) Notes ==========
-- CI gates (examples):
-- 1) Ledger balanced: select count(*) from public.v_fee_imbalances; -- expect 0
-- 2) Event codes exist: select count(*) from public.event_codes;     -- expect > 0
-- 3) Webhook DLQ under threshold (24h):
--    select count(*) from public.webhook_outbox where dead_letter and created_at>=now()-interval '24 hours';
