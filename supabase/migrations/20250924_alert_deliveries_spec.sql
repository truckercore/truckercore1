-- 20250924_alert_deliveries_spec.sql
-- Purpose: Align alert deliveries schema and metrics with spec.
-- Safe to re-run (idempotent). Non-destructive changes only.

-- ========== 1) Alert deliveries (queue + history) ==========
create table if not exists public.alert_deliveries (
  id uuid primary key default gen_random_uuid(),
  alert_id uuid not null,
  org_id uuid not null,
  code text not null,
  channel text not null check (channel in ('slack','teams','email','webhook')),
  target text not null,
  payload jsonb not null default '{}'::jsonb,
  attempts int not null default 0,
  last_error text null,
  next_attempt_at timestamptz null,
  dead_letter boolean not null default false,
  created_at timestamptz not null default now()
);

-- Ensure missing columns exist if table was previously created with a different shape
alter table if exists public.alert_deliveries
  add column if not exists alert_id uuid,
  add column if not exists org_id uuid,
  add column if not exists code text,
  add column if not exists channel text,
  add column if not exists target text,
  add column if not exists payload jsonb not null default '{}'::jsonb,
  add column if not exists attempts int not null default 0,
  add column if not exists last_error text,
  add column if not exists next_attempt_at timestamptz,
  add column if not exists dead_letter boolean not null default false,
  add column if not exists created_at timestamptz not null default now();

-- Add channel check constraint if missing
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'alert_deliveries_channel_chk'
  ) THEN
    ALTER TABLE public.alert_deliveries
      ADD CONSTRAINT alert_deliveries_channel_chk
      CHECK (channel in ('slack','teams','email','webhook'));
  END IF;
END$$;

-- Indexes: next-attempt (per spec) and org-time
create index if not exists idx_alert_deliveries_next
  on public.alert_deliveries (dead_letter, next_attempt_at nulls first);
create index if not exists idx_alert_deliveries_org_time
  on public.alert_deliveries (org_id, created_at desc);

-- ========== 2) Delivery endpoints registry ==========
-- If table doesn't exist, create per spec (uuid PK). If it exists, add missing columns/constraints.
create table if not exists public.notifier_endpoints (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  channel text not null check (channel in ('slack','teams','email','webhook')),
  target text not null,
  active boolean not null default true,
  signing_secret text null,
  created_at timestamptz not null default now(),
  unique (org_id, channel, target)
);

-- Backfill/augment existing table if shape differs
alter table if exists public.notifier_endpoints
  add column if not exists org_id uuid,
  add column if not exists active boolean not null default true,
  add column if not exists signing_secret text,
  add column if not exists created_at timestamptz not null default now();

-- Channel check on endpoints (guarded)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'notifier_endpoints_channel_chk'
  ) THEN
    ALTER TABLE public.notifier_endpoints
      ADD CONSTRAINT notifier_endpoints_channel_chk
      CHECK (channel in ('slack','teams','email','webhook'));
  END IF;
END$$;

-- Unique(org_id,channel,target) (guarded)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'notifier_endpoints_org_channel_target_key'
  ) THEN
    ALTER TABLE public.notifier_endpoints
      ADD CONSTRAINT notifier_endpoints_org_channel_target_key
      UNIQUE (org_id, channel, target);
  END IF;
END$$;

-- ========== 3) Suppression policy ==========
create table if not exists public.notifier_suppression_policy (
  code text primary key,
  window interval not null default interval '2 hours',
  priority int not null default 100
);

-- RLS enable and policies (read-only for authenticated)
alter table public.notifier_suppression_policy enable row level security;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='notifier_suppression_policy' AND policyname='notifier_suppression_read_all'
  ) THEN
    CREATE POLICY notifier_suppression_read_all ON public.notifier_suppression_policy
    FOR SELECT TO authenticated USING (true);
  END IF;
END$$;

-- ========== 4) Optional: dead letters archive ==========
create table if not exists public.alert_dead_letters (
  id uuid primary key,
  org_id uuid not null,
  code text not null,
  channel text not null,
  target text not null,
  payload jsonb not null,
  attempts int not null,
  last_error text,
  dead_letter_at timestamptz not null default now(),
  reason text null
);

-- ========== 5) RLS for tables (read-only by org for deliveries/endpoints) ==========
alter table public.alert_deliveries enable row level security;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='alert_deliveries' AND policyname='alert_deliveries_read_org'
  ) THEN
    CREATE POLICY alert_deliveries_read_org ON public.alert_deliveries
    FOR SELECT TO authenticated
    USING (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
  END IF;
END$$;

alter table public.notifier_endpoints enable row level security;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='notifier_endpoints' AND policyname='notifier_endpoints_read_org'
  ) THEN
    CREATE POLICY notifier_endpoints_read_org ON public.notifier_endpoints
    FOR SELECT TO authenticated
    USING (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
  END IF;
END$$;

-- ========== 6) Metrics views (per spec) ==========
-- 24h delivery health
create or replace view public.v_alert_delivery_24h as
select
  (select count(*) from public.alert_deliveries where created_at >= now() - interval '24 hours') as total_24h,
  (select count(*) from public.alert_deliveries where created_at >= now() - interval '24 hours' and dead_letter = false and last_error is null) as ok_24h,
  round(
    100.0 * (
      coalesce(nullif((select count(*) from public.alert_deliveries where created_at >= now() - interval '24 hours' and dead_letter = false and last_error is null),0),0)::numeric
      / greatest((select count(*) from public.alert_deliveries where created_at >= now() - interval '24 hours'),1)
    )
  , 2) as success_pct;

-- Top failures/targets (24h)
create or replace view public.v_alert_delivery_failures_24h as
select
  code, channel, target,
  count(*) filter (where last_error is not null) as failures,
  count(*) as total,
  round(100.0 * count(*) filter (where last_error is not null) / greatest(count(*),1), 2) as failure_pct,
  max(last_error) as sample_error
from public.alert_deliveries
where created_at >= now() - interval '24 hours'
group by code, channel, target
having count(*) filter (where last_error is not null) > 0
order by failure_pct desc, failures desc;

-- Per-target fail ratio 5m (for circuit breaker)
create or replace view public.v_notifier_target_failratio_5m as
select
  channel, target,
  sum(case when last_error is not null then 1 else 0 end)::numeric / greatest(count(*),1) as fail_ratio_5m
from public.alert_deliveries
where created_at >= now() - interval '5 minutes'
group by channel, target;

-- Dedup check (last hour)
create or replace view public.v_alert_delivery_dupes_1h as
with d as (
  select alert_id, channel, code, date_trunc('minute', created_at) as m, count(*) c
  from public.alert_deliveries
  where created_at >= now() - interval '1 hour'
  group by 1,2,3,4
  having count(*) > 1
)
select count(*) as dupes from d;
