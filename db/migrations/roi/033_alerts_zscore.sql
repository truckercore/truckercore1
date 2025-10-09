begin;

-- Z-score based anomaly over 30d window (per org daily totals)
create or replace view public.v_alert_roi_spike_anomaly_zscore as
with daily as (
  select org_id, date_trunc('day', created_at) as day, sum(amount_cents) as amt
  from public.ai_roi_events
  where created_at >= now() - interval '30 days'
  group by 1,2
), stats as (
  select org_id,
         avg(amt) as mean_amt,
         stddev_pop(amt) as sd_amt
  from daily
  group by org_id
), today as (
  select d.org_id, d.amt as amt_today, s.mean_amt, s.sd_amt,
         case when s.sd_amt is null or s.sd_amt = 0 then null else (d.amt - s.mean_amt) / s.sd_amt end as z
  from daily d
  join stats s using (org_id)
  where d.day = date_trunc('day', now())
)
select org_id, amt_today, mean_amt, sd_amt, z,
       (z is not null and z > 3) as is_p1,
       'Investigate ROI spike — validate baselines & recompute rollups'::text as remediation,
       '/functions/v1/roi/cron.refresh'::text as remediation_link
from today;

grant select on public.v_alert_roi_spike_anomaly_zscore to authenticated, anon;

commit;
