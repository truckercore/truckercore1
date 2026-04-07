-- ETA monitoring views
create or replace view v_eta_residuals as
select
  p.org_id,
  p.entity_id as trip_id,
  (p.prediction->>'eta_ts')::timestamptz as predicted_eta,
  (o.outcome->>'actual_arrival_ts')::timestamptz as actual_eta,
  extract(epoch from ((o.outcome->>'actual_arrival_ts')::timestamptz - (p.prediction->>'eta_ts')::timestamptz))::int as error_seconds,
  p.predicted_at
from ml_predictions p
join ml_outcomes o
  on o.org_id = p.org_id and o.kind='eta' and p.kind='eta' and o.entity_id = p.entity_id
where p.predicted_at > now() - interval '30 days';

create or replace view v_eta_daily_metrics as
select org_id,
       date_trunc('day', predicted_at) as day,
       avg(abs(error_seconds)) as mae_seconds,
       percentile_disc(0.5) within group (order by abs(error_seconds)) as p50_abs_err,
       percentile_disc(0.9) within group (order by abs(error_seconds)) as p90_abs_err
from v_eta_residuals
group by org_id, date_trunc('day', predicted_at);
