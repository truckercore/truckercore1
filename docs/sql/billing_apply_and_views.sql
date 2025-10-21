-- =============================================================
-- Billing runtime helpers & views (idempotent)
-- - Entitlements apply helper (SECURITY DEFINER)
-- - Webhook dedup table enhancements (event_id, status, payload, processed_at)
-- - Price catalog shim view (v_price_catalog)
-- - KPI and drift views
-- =============================================================

-- 1) Entitlements apply helper (pinned search_path)
create or replace function public.fn_billing_apply(
  p_user_id uuid,
  p_tier text,
  p_ai_enabled boolean,
  p_grace_until timestamptz default null
) returns void
language sql
security definer
set search_path=public
as $$
  insert into public.billing_profiles(user_id, tier, ai_enabled, grace_until, updated_at)
  values (p_user_id, p_tier, p_ai_enabled, p_grace_until, now())
  on conflict (user_id) do update
  set tier = excluded.tier,
      ai_enabled = excluded.ai_enabled,
      grace_until = excluded.grace_until,
      updated_at = now();
$$;

-- 2) Webhook dedup table enhancements
-- Ensure base table exists; align shape to include event_id, processed_at, status, payload
create table if not exists public.stripe_events_dedup (
  id text primary key,
  type text not null,
  received_at timestamptz not null default now()
);

-- Add columns idempotently
alter table public.stripe_events_dedup
  add column if not exists event_id text,
  add column if not exists processed_at timestamptz,
  add column if not exists status text,
  add column if not exists payload jsonb;

-- Unique constraint on event_id for dedup (separate from legacy primary key "id")
do $$ begin
  alter table public.stripe_events_dedup add constraint uniq_event unique (event_id);
exception when duplicate_object then null; end $$;

-- Backfill event_id from id for older rows (best-effort)
update public.stripe_events_dedup set event_id = id where event_id is null;

-- 3) Price catalog shim view: resolve to (price_id, product_id, feature_key, tier, is_ai)
-- Uses existing stripe_price_map table; product_id/feature_key may be null if not modeled
create or replace view public.v_price_catalog as
select
  m.price_id,
  null::text as product_id,
  null::text as feature_key,
  m.tier,
  m.ai_enabled as is_ai
from public.stripe_price_map m;

-- 4) KPIs (include as_of date)
create or replace view public.v_billing_kpis as
select
  now()::date as as_of,
  count(*) filter (where coalesce(ai_enabled,false)) as ai_accounts,
  count(*) filter (where coalesce(ai_enabled,false) and updated_at >= now() - interval '24 hours') as ai_activations_24h,
  (select count(*) from public.stripe_events_dedup where received_at >= now() - interval '24 hours') as webhooks_24h
from public.billing_profiles;

-- 5) Drift detection
create or replace view public.v_billing_drift as
select user_id, tier, ai_enabled, updated_at
from public.billing_profiles
where coalesce(ai_enabled,false) = true and coalesce(tier,'basic') <> 'ai';
