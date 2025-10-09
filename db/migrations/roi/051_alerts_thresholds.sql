begin;

-- Adjust explainability alert threshold to 98%
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
  (coalesce(explain_rate, 0) < 0.98) as is_warn,
  'Run OPA probe'::text as remediation,
  '/probes/ai/explainability'::text as remediation_link
from last24;

-- Export latency budget alert view (expects ai_metrics with metric 'roi_export_p95_seconds')
create or replace view public.v_alert_roi_export_latency as
with last1h as (
  select org_id, avg(value) as p95s
  from public.ai_metrics
  where metric = 'roi_export_p95_seconds' and ts >= now() - interval '1 hour'
  group by org_id
)
select org_id,
       coalesce(p95s, 0) as p95_seconds,
       (coalesce(p95s, 0) > 2.0) as is_regression,
       'Investigate ROI export performance'::text as remediation,
       '/functions/v1/roi/export_rollup?org_id=...'::text as remediation_link
from last1h;

grant select on public.v_alert_explainability_missing, public.v_alert_roi_export_latency to authenticated, anon;

-- Cost guard: flag orgs with unusually high ROI event counts today
create or replace view public.v_alert_roi_event_outliers as
with today as (
  select org_id, count(*) as events_today
  from public.ai_roi_events
  where created_at >= date_trunc('day', now())
  group by org_id
)
select org_id,
       events_today,
       (events_today > 10000) as is_outlier,
       'Validate event ingestion and attribution; consider throttling'::text as remediation,
       null::text as remediation_link
from today;

grant select on public.v_alert_roi_event_outliers to authenticated, anon;

commit;
