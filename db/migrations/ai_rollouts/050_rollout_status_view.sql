begin;

create or replace view public.ai_rollout_status as
select model_key,
       status as strategy,
       live_version_id::text as active,
       candidate_version_id::text as candidate,
       pct as canary_pct,
       now() - updated_at as age
from public.ai_model_rollouts
left join public.ai_model_serving using (model_key)
order by model_key;

grant select on public.ai_rollout_status to anon, authenticated;

commit;
