-- Models
insert into ai_models (key, owner) values
  ('eta','ai') on conflict (key) do nothing,
  ('match','ai') on conflict (key) do nothing,
  ('fraud','ai') on conflict (key) do nothing;

-- Active versions (point to your HTTP inference endpoints)
insert into ai_model_versions (model_id, version, artifact_url, framework, status, metrics)
select id, 'v0', :'ETA_MODEL_ENDPOINT', 'http', 'active', '{}'::jsonb
from ai_models where key='eta'
on conflict do nothing;

insert into ai_model_versions (model_id, version, artifact_url, framework, status, metrics)
select id, 'v0', :'MATCH_MODEL_ENDPOINT', 'http', 'active', '{}'::jsonb
from ai_models where key='match'
on conflict do nothing;

insert into ai_model_versions (model_id, version, artifact_url, framework, status, metrics)
select id, 'v0', :'FRAUD_MODEL_ENDPOINT', 'http', 'active', '{}'::jsonb
from ai_models where key='fraud'
on conflict do nothing;

-- Rollouts set to single on v0
insert into ai_rollouts (model_id, strategy, active_version_id)
select m.id, 'single', v.id
from ai_models m
join ai_model_versions v on v.model_id=m.id and v.version='v0'
on conflict (model_id) do nothing;

-- Demo inference/feedback (optional)
do $$
declare cid uuid;
begin
  insert into ai_inference_events (model_key, model_version_id, features, prediction)
  select 'eta', v.id,
         '{"distance_km":120,"avg_speed_hist":70,"hour_of_day":14,"day_of_week":2}'::jsonb,
         '{"eta_min":110}'::jsonb
  from ai_model_versions v
  join ai_models m on m.id=v.model_id and m.key='eta' and v.version='v0'
  returning correlation_id into cid;

  insert into ai_feedback_events (correlation_id, actual)
  values (cid, '{"eta_min":115}'::jsonb);
end$$;
