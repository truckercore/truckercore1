begin;

-- ROI exports registry (evidence-ready)
create table if not exists public.roi_exports (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  period_month date not null,                       -- yyyy-mm-01
  report_id uuid not null default gen_random_uuid(),
  storage_url text not null,                        -- s3 or storage path
  hash_sha256 text not null,
  created_at timestamptz not null default now()
);
create index if not exists idx_roi_exports_org_month on public.roi_exports(org_id, period_month desc);

-- Compliance evidence ledger
create table if not exists public.compliance_evidence (
  id bigserial primary key,
  org_id uuid not null,
  artifact text not null,
  hash_sha256 text,
  source text not null,
  created_at timestamptz not null default now()
);
create index if not exists idx_compliance_evidence_org_time on public.compliance_evidence(org_id, created_at desc);

-- Future-proofing: attribution method on events (cents table variant)
alter table if exists public.ai_roi_events
  add column if not exists source text,
  add column if not exists is_backfill boolean not null default false,
  add column if not exists attribution_method text not null default 'PSM_v0',
  add column if not exists attribution_method_next text;

-- Rollup freshness meta already exists in some repos; create if absent
create table if not exists public.ai_roi_rollup_meta (
  id boolean primary key default true,
  last_refresh_at timestamptz
);

-- Alerts: rollup stale >24h
create or replace view public.v_alert_rollup_stale_24h as
select 
  case when last_refresh_at is null then 'unknown' else 'stale_24h' end as alert_key,
  (now() - coalesce(last_refresh_at, timestamp 'epoch')) as age,
  (last_refresh_at is null or now() - last_refresh_at > interval '24 hours') as is_alert,
  'Recompute rollup'::text as remediation,
  '/functions/v1/roi/cron.refresh'::text as remediation_link
from public.ai_roi_rollup_meta;

-- Alerts: spike anomaly (reuse existing 7d median spike view if present)
create or replace view public.v_alert_roi_spike_anomaly as
select 
  org_id,
  amt_today, med_7d, multiple,
  (multiple is not null and multiple > 3) as is_p1,
  'Validate baselines & recent event bursts'::text as remediation,
  '/functions/v1/roi/alerts/anomalies'::text as remediation_link
from public.v_ai_roi_spike_alerts;

-- Alerts: explainability missing (using ai_metrics table with metric='opa_explain_rate')
create or replace view public.v_alert_explainability_missing as
with last24 as (
  select org_id, avg(value) as explain_rate
  from public.ai_metrics
  where metric = 'opa_explain_rate' and ts >= now() - interval '24 hours'
  group by org_id
)
select 
  org_id,
  coalesce(explain_rate, 0) as explain_rate,
  (coalesce(explain_rate, 0) < 0.9) as is_warn,
  'Run OPA probe'::text as remediation,
  '/probes/ai/explainability'::text as remediation_link
from last24;

-- Optional helper: lightweight get_entitlement wrapper matching Danger expectations
create or replace function public.get_entitlement(p_org_id uuid, p_feature_key text)
returns table (enabled boolean)
language sql stable as $$
  select coalesce((select enabled from public.entitlements where org_id = p_org_id and feature_key = p_feature_key limit 1), false) as enabled;
$$;

commit;
