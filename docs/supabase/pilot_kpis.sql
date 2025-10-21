-- Pilot KPI views and refresh function (v1)
-- Location: docs/supabase/pilot_kpis.sql

-- Materialized view: pilot funnel (last 90 days snapshotable)
create materialized view if not exists public.mv_pilot_funnel as
select
  org_id,
  date_trunc('day', created_at) as day,
  count(*) filter (where action = 'proposed')::int as proposed,
  count(*) filter (where action = 'approved')::int as approved,
  count(*) filter (where action = 'applied')::int as applied
from public.autonomous_plan_events -- expected audit of plan lifecycle
group by org_id, date_trunc('day', created_at);
create index if not exists idx_mv_funnel_org_day on public.mv_pilot_funnel(org_id, day);

-- Materialized view: pilot ROI (uplift metrics vs baseline)
-- Assumes a fact table public.load_metrics with baseline and actuals per load/day
create materialized view if not exists public.mv_pilot_roi as
select
  org_id,
  date_trunc('day', day) as day,
  avg(actual_cph - baseline_cph) as cph_uplift,
  avg(baseline_deadhead_mi - actual_deadhead_mi) as deadhead_saved_mi,
  sum(delay_risk_alerts)::int as delay_risk_alerts,
  sum(delay_risk_mitigated)::int as delay_risk_mitigated
from public.load_metrics
group by org_id, date_trunc('day', day);
create index if not exists idx_mv_roi_org_day on public.mv_pilot_roi(org_id, day);

-- Refresh helper (nightly)
create or replace function public.fn_kpis_refresh_day()
returns void language sql as $$
  refresh materialized view concurrently public.mv_pilot_funnel;
  refresh materialized view concurrently public.mv_pilot_roi;
$$;
