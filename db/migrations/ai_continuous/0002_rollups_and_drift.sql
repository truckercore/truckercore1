begin;

create or replace function ai_eta_feedback_since(minutes_back int)
returns table (count int)
language sql stable as $$
  select count(*)::int from ai_feedback_events
  where created_at >= (now() - make_interval(mins => minutes_back));
$$;
grant execute on function ai_eta_feedback_since(int) to service_role;

create or replace function ai_eta_rollup(p_minutes_back int default 1440)
returns void language plpgsql security definer as $$
declare
  w_start timestamptz := now() - make_interval(mins => p_minutes_back);
  w_end   timestamptz := now();
begin
  insert into ai_accuracy_rollups (model_key, model_version_id, window_start, window_end, metrics)
  select
    'eta',
    inf.model_version_id,
    w_start, w_end,
    jsonb_build_object(
      'mae_min', avg(abs((inf.prediction->>'eta_min')::numeric - (fb.actual->>'eta_min')::numeric)),
      'rmse_min', sqrt(avg(power((inf.prediction->>'eta_min')::numeric - (fb.actual->>'eta_min')::numeric,2))),
      'n', count(*)
    )
  from ai_inference_events inf
  join ai_feedback_events fb using (correlation_id)
  where inf.model_key = 'eta'
    and inf.created_at >= w_start and inf.created_at < w_end
  group by inf.model_version_id;
end; $$;
grant execute on function ai_eta_rollup(int) to service_role;

create or replace function ai_eta_drift_snapshot(p_minutes_back int default 1440)
returns void language plpgsql security definer as $$
declare
  w_start timestamptz := now() - make_interval(mins => p_minutes_back);
  w_end   timestamptz := now();
begin
  insert into ai_drift_snapshots (model_key, window_start, window_end, stats)
  select 'eta', w_start, w_end,
         jsonb_build_object(
           'distance_km_mean', avg( (features->>'distance_km')::numeric ),
           'avg_speed_hist_mean', avg( (features->>'avg_speed_hist')::numeric ),
           'hour_of_day_mean', avg( (features->>'hour_of_day')::numeric ),
           'day_of_week_mean', avg( (features->>'day_of_week')::numeric ),
           'psi', 0.0
         )
  from ai_inference_events
  where model_key='eta' and created_at >= w_start and created_at < w_end;
end; $$;
grant execute on function ai_eta_drift_snapshot(int) to service_role;

commit;
