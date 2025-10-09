begin;
create table if not exists ai_bias_metrics (
  id bigserial primary key,
  model_key text not null,
  model_version_id uuid,
  window_start timestamptz not null,
  window_end timestamptz not null,
  metrics jsonb not null,
  created_at timestamptz default now()
);

create or replace function ai_bias_rollup_eta(p_minutes_back int default 1440)
returns void
language plpgsql
security definer
as $$
declare
  w_start timestamptz := now() - make_interval(mins => p_minutes_back);
  w_end   timestamptz := now();
begin
  insert into ai_bias_metrics (model_key, model_version_id, window_start, window_end, metrics)
  select
    'eta',
    inf.model_version_id,
    w_start, w_end,
    jsonb_build_object(
      'groups', jsonb_object_agg(bucket, jsonb_build_object(
         'n', count(*),
         'mae_min', avg(abs((inf.prediction->>'eta_min')::numeric - (fb.actual->>'eta_min')::numeric))
      ))
    )
  from (
    select i.*, case when (i.features->>'hour_of_day')::int between 7 and 19 then 'day' else 'night' end as bucket
    from ai_inference_events i
    where i.model_key='eta' and i.created_at >= w_start and i.created_at < w_end
  ) inf
  join ai_feedback_events fb using (correlation_id)
  group by inf.model_version_id
  on conflict do nothing;
end; $$;

grant execute on function ai_bias_rollup_eta(int) to service_role;
commit;