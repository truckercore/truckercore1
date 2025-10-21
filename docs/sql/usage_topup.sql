-- =============================================================
-- Usage Top-up Offers + ops.cron_health compatibility (idempotent)
-- =============================================================

-- 0) Compatibility: expose cron health under ops schema for smoke checks
DO $$ BEGIN
  CREATE SCHEMA IF NOT EXISTS ops;
EXCEPTION WHEN duplicate_schema THEN NULL; END $$;

CREATE OR REPLACE VIEW ops.cron_health AS
SELECT * FROM public.v_cron_health;

-- 1) Top-up offers ledger (soft-limit upsell)
CREATE TABLE IF NOT EXISTS public.topup_offers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL,
  feature text NOT NULL,
  period text NOT NULL,                  -- e.g., 'mtd'
  threshold int NOT NULL,                -- soft-limit threshold that triggered (e.g., 80)
  offered_at timestamptz NOT NULL DEFAULT now(),
  accepted boolean NOT NULL DEFAULT false,
  accepted_at timestamptz NULL,
  stripe_session_url text NULL,
  meta jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (org_id, feature, period, date_trunc('day', offered_at))
);
-- notifier flag (idempotent)
ALTER TABLE IF EXISTS public.topup_offers
  ADD COLUMN IF NOT EXISTS notified boolean NOT NULL DEFAULT false;

ALTER TABLE public.topup_offers ENABLE ROW LEVEL SECURITY;
-- Read/write within org (admins or service-role typically write)
DO $$ BEGIN
  CREATE POLICY topup_offers_ro ON public.topup_offers
    FOR SELECT USING (public.app_org() = org_id);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY topup_offers_rw ON public.topup_offers
    FOR INSERT WITH CHECK (public.app_org() = org_id);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 2) Soft-limit candidates (>= 80% of soft_limit and below hard_limit)
-- If a dedicated v_usage_consumed view does not exist, compute current-month usage inline
CREATE OR REPLACE VIEW public.v_quota_softlimit_candidates AS
WITH used AS (
  SELECT org_id, feature_key AS feature, sum(units)::bigint AS units_period
  FROM public.usage_events
  WHERE date_trunc('month', at) = date_trunc('month', now())
  GROUP BY org_id, feature_key
)
SELECT
  q.org_id,
  q.feature_key AS feature,
  q.soft_limit,
  q.hard_limit,
  'mtd'::text AS period,
  COALESCE(u.units_period, 0) AS units_period,
  CASE WHEN q.soft_limit > 0 THEN round((COALESCE(u.units_period,0)::numeric / q.soft_limit) * 100.0) ELSE NULL END AS pct_of_soft
FROM public.usage_quotas q
LEFT JOIN used u ON u.org_id = q.org_id AND u.feature = q.feature_key
WHERE q.soft_limit IS NOT NULL AND q.soft_limit > 0
  AND COALESCE(u.units_period, 0) >= (q.soft_limit * 0.80)
  AND (q.hard_limit IS NULL OR COALESCE(u.units_period, 0) < q.hard_limit);

-- 3) RPC: create (or return existing same-day) top-up offer
CREATE OR REPLACE FUNCTION public.fn_topup_offer_create(
  p_org_id uuid,
  p_feature text,
  p_period text,
  p_threshold int
) RETURNS public.topup_offers
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=public
AS $$
DECLARE v public.topup_offers;
BEGIN
  -- Idempotent per day/org/feature/period
  INSERT INTO public.topup_offers(org_id, feature, period, threshold, meta)
  VALUES (p_org_id, p_feature, p_period, p_threshold, jsonb_build_object('source','soft_limit'))
  ON CONFLICT (org_id, feature, period, date_trunc('day', offered_at))
  DO UPDATE SET threshold = EXCLUDED.threshold
  RETURNING * INTO v;

  RETURN v;
END $$;

REVOKE ALL ON FUNCTION public.fn_topup_offer_create(uuid,text,text,int) FROM public;
GRANT EXECUTE ON FUNCTION public.fn_topup_offer_create(uuid,text,text,int) TO authenticated, service_role;


-- =============================================================
-- Top-up extensions: columns, overloaded fn, candidate view shape, effective quota
-- =============================================================

-- 1) Extend topup_offers with fields expected by dashboards/CI (idempotent)
alter table if exists public.topup_offers
  add column if not exists feature_key text,
  add column if not exists units bigint,
  add column if not exists status text not null default 'active',
  add column if not exists expires_at timestamptz,
  add column if not exists created_at timestamptz not null default now();

-- Backfill feature_key from legacy column if present but null
update public.topup_offers set feature_key = coalesce(feature_key, feature) where feature_key is null;

-- 2) Overloaded helper to create an offer with (org, feature_key, units, reason)
-- Keeps original function signature for compatibility.
create or replace function public.fn_topup_offer_create(
  p_org_id uuid,
  p_feature_key text,
  p_units int,
  p_reason text
) returns public.topup_offers
language plpgsql
security definer
set search_path=public
as $$
declare v public.topup_offers;
begin
  -- Idempotent per day/org/feature/period; store reason in meta
  insert into public.topup_offers(org_id, feature, feature_key, period, threshold, units, status, expires_at, meta)
  values (
    p_org_id,
    p_feature_key,
    p_feature_key,
    'mtd',                 -- monthly period for usage
    0,                     -- threshold not applicable in this variant
    p_units,
    'issued',              -- issued by trial/offer
    case when lower(coalesce(p_reason,'')) like '%trial%' then now() + interval '14 days' end,
    jsonb_build_object('source','soft_limit','reason', coalesce(p_reason,'manual'))
  )
  on conflict (org_id, feature, period, date_trunc('day', offered_at))
  do update set
    units = coalesce(public.topup_offers.units, 0) + excluded.units,
    status = excluded.status,
    expires_at = coalesce(excluded.expires_at, public.topup_offers.expires_at),
    meta = public.topup_offers.meta || jsonb_build_object('upserted', true)
  returning * into v;

  return v;
end $$;
revoke all on function public.fn_topup_offer_create(uuid,text,int,text) from public;
grant execute on function public.fn_topup_offer_create(uuid,text,int,text) to authenticated, service_role;

-- 3) Adjust soft-limit candidates view shape to expose feature_key and first_seen_at
create or replace view public.v_quota_softlimit_candidates as
with used as (
  select org_id, feature_key as feature, sum(units)::bigint as units_period
  from public.usage_events
  where date_trunc('month', at) = date_trunc('month', now())
  group by org_id, feature_key
)
select
  q.org_id,
  q.feature_key,
  q.soft_limit,
  q.hard_limit,
  'mtd'::text as period,
  coalesce(u.units_period, 0) as units_period,
  case when q.soft_limit > 0 then round((coalesce(u.units_period,0)::numeric / q.soft_limit) * 100.0) else null end as pct_of_soft,
  date_trunc('day', now()) as first_seen_at -- minimal placeholder; refine if you track history
from public.usage_quotas q
left join used u on u.org_id = q.org_id and u.feature = q.feature_key
where q.soft_limit is not null and q.soft_limit > 0
  and coalesce(u.units_period, 0) >= (q.soft_limit * 0.80)
  and (q.hard_limit is null or coalesce(u.units_period, 0) < q.hard_limit);

-- 4) Effective quota view (base soft_limit + active/issued, non-expired top-ups)
create or replace view public.v_quota_effective as
with u24 as (
  select org_id, feature_key, sum(units)::bigint as usage_24h
  from public.usage_events
  where at > now() - interval '24 hours'
  group by org_id, feature_key
),
active_topups as (
  select org_id, coalesce(feature_key, feature) as feature_key,
         sum(coalesce(units,0))::bigint as topup_units_active
  from public.topup_offers
  where coalesce(status,'active') in ('active','issued')
    and (expires_at is null or expires_at > now())
  group by org_id, coalesce(feature_key, feature)
)
select
  q.org_id,
  q.feature_key,
  coalesce(u.usage_24h,0) as usage_24h,
  q.soft_limit as base_quota,
  coalesce(t.topup_units_active,0) as topup_units_active,
  coalesce(q.soft_limit,0) + coalesce(t.topup_units_active,0) as effective_quota
from public.usage_quotas q
left join u24 u on u.org_id = q.org_id and u.feature_key = q.feature_key
left join active_topups t on t.org_id = q.org_id and t.feature_key = q.feature_key;

-- =============================================================
-- Usage Top-up Offers + ops.cron_health compatibility (idempotent)
-- =============================================================

-- 0) Compatibility: expose cron health under ops schema for smoke checks
DO $$ BEGIN
  CREATE SCHEMA IF NOT EXISTS ops;
EXCEPTION WHEN duplicate_schema THEN NULL; END $$;

CREATE OR REPLACE VIEW ops.cron_health AS
SELECT * FROM public.v_cron_health;

-- 1) Top-up offers ledger (soft-limit upsell)
CREATE TABLE IF NOT EXISTS public.topup_offers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL,
  feature text NOT NULL,
  period text NOT NULL,                  -- e.g., 'mtd'
  threshold int NOT NULL,                -- soft-limit threshold that triggered (e.g., 80)
  offered_at timestamptz NOT NULL DEFAULT now(),
  accepted boolean NOT NULL DEFAULT false,
  accepted_at timestamptz NULL,
  stripe_session_url text NULL,
  meta jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (org_id, feature, period, date_trunc('day', offered_at))
);
-- notifier flag (idempotent)
ALTER TABLE IF EXISTS public.topup_offers
  ADD COLUMN IF NOT EXISTS notified boolean NOT NULL DEFAULT false;

ALTER TABLE public.topup_offers ENABLE ROW LEVEL SECURITY;
-- Read/write within org (admins or service-role typically write)
DO $$ BEGIN
  CREATE POLICY topup_offers_ro ON public.topup_offers
    FOR SELECT USING (public.app_org() = org_id);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY topup_offers_rw ON public.topup_offers
    FOR INSERT WITH CHECK (public.app_org() = org_id);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 2) Soft-limit candidates (>= 80% of soft_limit and below hard_limit)
-- If a dedicated v_usage_consumed view does not exist, compute current-month usage inline
CREATE OR REPLACE VIEW public.v_quota_softlimit_candidates AS
WITH used AS (
  SELECT org_id, feature_key AS feature, sum(units)::bigint AS units_period
  FROM public.usage_events
  WHERE date_trunc('month', at) = date_trunc('month', now())
  GROUP BY org_id, feature_key
)
SELECT
  q.org_id,
  q.feature_key AS feature,
  q.soft_limit,
  q.hard_limit,
  'mtd'::text AS period,
  COALESCE(u.units_period, 0) AS units_period,
  CASE WHEN q.soft_limit > 0 THEN round((COALESCE(u.units_period,0)::numeric / q.soft_limit) * 100.0) ELSE NULL END AS pct_of_soft
FROM public.usage_quotas q
LEFT JOIN used u ON u.org_id = q.org_id AND u.feature = q.feature_key
WHERE q.soft_limit IS NOT NULL AND q.soft_limit > 0
  AND COALESCE(u.units_period, 0) >= (q.soft_limit * 0.80)
  AND (q.hard_limit IS NULL OR COALESCE(u.units_period, 0) < q.hard_limit);

-- 3) RPC: create (or return existing same-day) top-up offer
CREATE OR REPLACE FUNCTION public.fn_topup_offer_create(
  p_org_id uuid,
  p_feature text,
  p_period text,
  p_threshold int
) RETURNS public.topup_offers
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=public
AS $$
DECLARE v public.topup_offers;
BEGIN
  -- Idempotent per day/org/feature/period
  INSERT INTO public.topup_offers(org_id, feature, period, threshold, meta)
  VALUES (p_org_id, p_feature, p_period, p_threshold, jsonb_build_object('source','soft_limit'))
  ON CONFLICT (org_id, feature, period, date_trunc('day', offered_at))
  DO UPDATE SET threshold = EXCLUDED.threshold
  RETURNING * INTO v;

  RETURN v;
END $$;

REVOKE ALL ON FUNCTION public.fn_topup_offer_create(uuid,text,text,int) FROM public;
GRANT EXECUTE ON FUNCTION public.fn_topup_offer_create(uuid,text,text,int) TO authenticated, service_role;


-- =============================================================
-- Top-up extensions: columns, overloaded fn, candidate view shape, effective quota
-- =============================================================

-- 1) Extend topup_offers with fields expected by dashboards/CI (idempotent)
alter table if exists public.topup_offers
  add column if not exists feature_key text,
  add column if not exists units bigint,
  add column if not exists status text not null default 'active',
  add column if not exists expires_at timestamptz,
  add column if not exists created_at timestamptz not null default now();

-- Backfill feature_key from legacy column if present but null
update public.topup_offers set feature_key = coalesce(feature_key, feature) where feature_key is null;

-- 2) Overloaded helper to create an offer with (org, feature_key, units, reason)
-- Keeps original function signature for compatibility.
create or replace function public.fn_topup_offer_create(
  p_org_id uuid,
  p_feature_key text,
  p_units int,
  p_reason text
) returns public.topup_offers
language plpgsql
security definer
set search_path=public
as $$
declare v public.topup_offers;
begin
  -- Idempotent per day/org/feature/period; store reason in meta
  insert into public.topup_offers(org_id, feature, feature_key, period, threshold, units, status, expires_at, meta)
  values (
    p_org_id,
    p_feature_key,
    p_feature_key,
    'mtd',                 -- monthly period for usage
    0,                     -- threshold not applicable in this variant
    p_units,
    'issued',              -- issued by trial/offer
    case when lower(coalesce(p_reason,'')) like '%trial%' then now() + interval '14 days' end,
    jsonb_build_object('source','soft_limit','reason', coalesce(p_reason,'manual'))
  )
  on conflict (org_id, feature, period, date_trunc('day', offered_at))
  do update set
    units = coalesce(public.topup_offers.units, 0) + excluded.units,
    status = excluded.status,
    expires_at = coalesce(excluded.expires_at, public.topup_offers.expires_at),
    meta = public.topup_offers.meta || jsonb_build_object('upserted', true)
  returning * into v;

  return v;
end $$;
revoke all on function public.fn_topup_offer_create(uuid,text,int,text) from public;
grant execute on function public.fn_topup_offer_create(uuid,text,int,text) to authenticated, service_role;

-- 3) Adjust soft-limit candidates view shape to expose feature_key and first_seen_at
create or replace view public.v_quota_softlimit_candidates as
with used as (
  select org_id, feature_key as feature, sum(units)::bigint as units_period
  from public.usage_events
  where date_trunc('month', at) = date_trunc('month', now())
  group by org_id, feature_key
)
select
  q.org_id,
  q.feature_key,
  q.soft_limit,
  q.hard_limit,
  'mtd'::text as period,
  coalesce(u.units_period, 0) as units_period,
  case when q.soft_limit > 0 then round((coalesce(u.units_period,0)::numeric / q.soft_limit) * 100.0) else null end as pct_of_soft,
  date_trunc('day', now()) as first_seen_at -- minimal placeholder; refine if you track history
from public.usage_quotas q
left join used u on u.org_id = q.org_id and u.feature = q.feature_key
where q.soft_limit is not null and q.soft_limit > 0
  and coalesce(u.units_period, 0) >= (q.soft_limit * 0.80)
  and (q.hard_limit is null or coalesce(u.units_period, 0) < q.hard_limit);

-- 4) Effective quota view (base soft_limit + active/issued, non-expired top-ups)
create or replace view public.v_quota_effective as
with u24 as (
  select org_id, feature_key, sum(units)::bigint as usage_24h
  from public.usage_events
  where at > now() - interval '24 hours'
  group by org_id, feature_key
),
active_topups as (
  select org_id, coalesce(feature_key, feature) as feature_key,
         sum(coalesce(units,0))::bigint as topup_units_active
  from public.topup_offers
  where coalesce(status,'active') in ('active','issued')
    and (expires_at is null or expires_at > now())
  group by org_id, coalesce(feature_key, feature)
)
select
  q.org_id,
  q.feature_key,
  coalesce(u.usage_24h,0) as usage_24h,
  q.soft_limit as base_quota,
  coalesce(t.topup_units_active,0) as topup_units_active,
  coalesce(q.soft_limit,0) + coalesce(t.topup_units_active,0) as effective_quota
from public.usage_quotas q
left join u24 u on u.org_id = q.org_id and u.feature_key = q.feature_key
left join active_topups t on t.org_id = q.org_id and t.feature_key = q.feature_key;

-- 5) Autocreate lingering top-ups (idempotent)
create or replace function public.topup_autocreate_lingering(days_back int default 7)
returns int language plpgsql as $$
declare n int:=0;
begin
  with stale as (
    select org_id, feature_key
    from public.v_quota_softlimit_candidates
    where (date_trunc('day', now()) - interval '1 day'*days_back) >= date_trunc('day', now()) - interval '1 day'*days_back
  ),
  ins as (
    select public.fn_topup_offer_create(org_id, feature_key, 1000, 'auto_lingering_'||to_char(now(),'YYYYMMDD')) as id
    from stale
  )
  select count(*) into n from ins;
  return n;
exception when unique_violation then
  return n;
end $$;

-- 6) Top-up SLO views
create or replace view public.v_topup_stale as
select * from public.topup_offers
where coalesce(accepted,false) = false
  and offered_at < now() - interval '7 days';

create or replace view public.v_topup_kpis as
select
  count(*) filter (where accepted and offered_at > now() - interval '30 days') as accepted_30d,
  count(*) filter (where coalesce(accepted,false) = false and offered_at > now() - interval '30 days') as pending_30d
from public.topup_offers;
