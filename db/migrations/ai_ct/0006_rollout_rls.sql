begin;

-- RLS posture / privileges for rollout control-plane tables
-- Reads allowed to authenticated; writes only via service_role
revoke insert, update, delete on public.ai_model_serving  from authenticated;
revoke insert, update, delete on public.ai_model_rollouts from authenticated;
grant  select                   on public.ai_model_serving, public.ai_model_rollouts to authenticated;

commit;
