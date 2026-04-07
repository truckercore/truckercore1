begin;

create or replace view ai_eta_health as
select
  (select (metrics->>'mae_min')::numeric from ai_accuracy_rollups where model_key='eta' order by created_at desc limit 1) as mae_min,
  (select (metrics->>'rmse_min')::numeric from ai_accuracy_rollups where model_key='eta' order by created_at desc limit 1) as rmse_min,
  (select (stats->>'psi')::numeric from ai_drift_snapshots where model_key='eta' order by created_at desc limit 1) as psi,
  (select count(*) from ai_inference_events where created_at>now()-interval '1 hour') as inferences_1h,
  (select now()-max(created_at) from ai_inference_events) as last_inf_age;

comment on view ai_eta_health is 'Quick operational view for ETA model health.';

commit;
