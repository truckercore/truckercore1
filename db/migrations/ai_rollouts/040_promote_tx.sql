begin;

-- ai_promote_tx: single-transaction promotion helper with advisory lock and audit
-- Adapted to this repository's rollout schema (ai_model_rollouts/model_key-based and ai_model_serving)

create table if not exists ai_promo_audit(
  id bigserial primary key,
  model_key text not null,
  action text not null,
  actor text not null,
  snapshot jsonb not null,
  created_at timestamptz default now()
);

create or replace function ai_promote_tx(
  p_model_key text,
  p_action text,                                     -- 'start_canary' | 'increase_canary' | 'finish'
  p_candidate text default null,                     -- version id (text/uuid)
  p_pct int default null,
  p_actor text default 'admin-key'
) returns json
language plpgsql
security definer
as $$
declare
  v_now timestamptz := now();
  v_lock_key bigint;
  v_roll record;
  v_live text;
begin
  -- Model-scoped advisory lock (stable 64-bit from model_key)
  v_lock_key := ('x'||substr(encode(digest(p_model_key,'sha1'),'hex'),1,16))::bit(64)::bigint;
  perform pg_advisory_xact_lock(v_lock_key);

  -- Ensure serving row exists (baseline live version may be null initially)
  select live_version_id into v_live from ai_model_serving where model_key = p_model_key for update;
  if not found then
    insert into ai_model_serving(model_key, live_version_id)
    values (p_model_key, coalesce(p_candidate, ''))
    on conflict (model_key) do nothing;
    select live_version_id into v_live from ai_model_serving where model_key = p_model_key for update;
  end if;

  -- Lock rollout row for update (create if missing on start)
  select * into v_roll from ai_model_rollouts where model_key = p_model_key for update;

  if p_action = 'start_canary' then
    if p_candidate is null then raise exception 'candidate required'; end if;

    if not found then
      insert into ai_model_rollouts(model_key, baseline_version_id, candidate_version_id, status, pct, window_min, created_at, updated_at)
      values (p_model_key, v_live, p_candidate, 'canary', coalesce(p_pct, 10), 60, v_now, v_now);
    else
      update ai_model_rollouts
        set baseline_version_id = v_live,
            candidate_version_id = p_candidate,
            status = 'canary',
            pct = coalesce(p_pct, 10),
            updated_at = v_now
        where model_key = p_model_key;
    end if;

  elsif p_action = 'increase_canary' then
    if p_pct is null then raise exception 'pct required'; end if;

    if not found then
      raise exception 'no rollout row to increase for %', p_model_key;
    end if;

    update ai_model_rollouts
      set pct = greatest(coalesce(pct, 0), p_pct),
          updated_at = v_now
      where model_key = p_model_key
      returning * into v_roll;

  elsif p_action = 'finish' then
    if not found or v_roll.candidate_version_id is null then
      raise exception 'no candidate to promote';
    end if;

    -- Activate candidate atomically
    update ai_model_serving
      set live_version_id = v_roll.candidate_version_id,
          updated_at = v_now
      where model_key = p_model_key;

    -- Close rollout
    update ai_model_rollouts
      set status = 'closed',
          pct = 100,
          updated_at = v_now
      where model_key = p_model_key;

  else
    raise exception 'unknown action %', p_action;
  end if;

  -- Audit snapshot
  insert into ai_promo_audit(model_key, action, actor, snapshot, created_at)
  values (
    p_model_key,
    p_action,
    p_actor,
    jsonb_strip_nulls((select to_jsonb(r) from (select * from ai_model_rollouts where model_key = p_model_key) r)),
    v_now
  );

  return json_build_object('ok', true, 'model_key', p_model_key, 'action', p_action, 'ts', v_now);
end;
$$;

grant execute on function ai_promote_tx(text,text,text,int,text) to service_role;

commit;
