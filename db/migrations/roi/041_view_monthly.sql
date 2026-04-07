begin;

-- Monthly ROI view expected by exec_roi_report function
-- Aggregates daily rollups (cents) to monthly USD per org.
-- Note: org_name/baseline_note/anomalies_count are placeholders; adjust when org directory and anomaly/baseline summaries exist.
create or replace view public.v_ai_roi_monthly as
with m as (
  select
    org_id,
    date_trunc('month', day)::date as period,
    coalesce(sum(fuel_cents), 0)   as fuel_cents,
    coalesce(sum(hos_cents), 0)    as hos_cents,
    coalesce(sum(promo_cents), 0)  as promo_cents,
    coalesce(sum(total_cents), 0)  as total_cents
  from public.ai_roi_rollup_day
  group by 1,2
)
select
  m.org_id,
  null::text as org_name,
  m.period,
  round((m.fuel_cents  / 100.0)::numeric, 2) as fuel_savings_usd,
  round((m.hos_cents   / 100.0)::numeric, 2) as hos_savings_usd,
  round((m.promo_cents / 100.0)::numeric, 2) as promo_uplift_usd,
  0::int as anomalies_count,
  null::text as baseline_note
from m;

commit;
