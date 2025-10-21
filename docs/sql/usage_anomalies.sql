-- Anomaly & drift guards (cheap + loud)

-- Z-score vs trailing 8 weeks per org/feature; alert where |z| >= 3
create or replace view public.v_usage_anomaly as
with w as (
  select org_id,
         feature_key,
         period,
         total_units,
         avg(total_units) over (partition by org_id, feature_key order by period rows between 8 preceding and 1 preceding) as mu,
         stddev_samp(total_units) over (partition by org_id, feature_key order by period rows between 8 preceding and 1 preceding) as sigma
  from public.usage_monthly
)
select *,
       case when sigma is null or sigma = 0 then 0
            else (total_units - mu)/sigma end as z
from w
where period >= date_trunc('month', now()) - interval '1 month'
  and abs(coalesce((total_units - mu)/(nullif(sigma,0)),0)) >= 3;

-- Reconciliation drift severity (assumes v_usage_sync_drift exists)
create or replace view public.v_usage_sync_drift_sev as
select *,
  case when abs(delta) >= 100 then 'p1'
       when abs(delta) >= 10  then 'p2'
       else 'p3' end as severity
from public.v_usage_sync_drift;
