begin;

-- Global defaults (fallback) — one row per key
create table if not exists public.ai_roi_baseline_defaults (
  key text primary key,                           -- 'fuel_price_usd_per_gal', 'hos_violation_cost_usd'
  value numeric not null,
  snapshot_id uuid not null default gen_random_uuid(),
  effective_at timestamptz not null default now(),
  comment text
);

-- Per-org overrides (can have multiple snapshots over time)
create table if not exists public.ai_roi_baselines (
  org_id uuid not null,
  key text not null,
  value numeric not null,
  snapshot_id uuid not null default gen_random_uuid(),
  effective_at timestamptz not null default now(),
  comment text,
  primary key (org_id, key, snapshot_id)
);

-- Effective baseline resolver (source = 'org' or 'default')
create or replace view public.v_ai_roi_baseline_effective as
with org_latest as (
  select distinct on (org_id, key)
    org_id, key, value, snapshot_id, effective_at, 'org'::text as source
  from public.ai_roi_baselines
  order by org_id, key, effective_at desc
),
org_ids as (
  select distinct org_id from public.ai_roi_baselines
),
joined as (
  select
    oids.org_id,
    d.key,
    coalesce(ol.value, d.value) as value,
    coalesce(ol.snapshot_id, d.snapshot_id) as snapshot_id,
    coalesce(ol.effective_at, d.effective_at) as effective_at,
    coalesce(ol.source, 'default') as source
  from org_ids oids
  cross join public.ai_roi_baseline_defaults d
  left join org_latest ol
    on ol.org_id = oids.org_id and ol.key = d.key
)
select * from joined;

commit;
