begin;
create or replace view ai_health as
with
p as (select count(*) as n_pred from ai_inference_events where created_at > now()-interval '24 hours'),
f as (select count(*) as n_fb from ai_feedback_events where created_at > now()-interval '24 hours'),
m as (
  select coalesce(avg((metrics->>'mae_min')::numeric),null) as mae_24h,
         coalesce(avg((metrics->>'rmse_min')::numeric),null) as rmse_24h
  from ai_accuracy_rollups
  where window_end > now()-interval '24 hours' and model_key='eta'
),
d as (
  select (stats->>'psi')::numeric as psi, created_at
  from ai_drift_snapshots
  where model_key='eta'
  order by created_at desc limit 1
),
l as (
  select coalesce(avg(latency_ms),null) as p50_ms,
         percentile_cont(0.95) within group (order by latency_ms) as p95_ms
  from ai_inference_events
  where created_at > now()-interval '1 hour' and model_key='eta'
)
select p.n_pred, f.n_fb, m.mae_24h, m.rmse_24h, d.psi, l.p50_ms, l.p95_ms;
commit;
