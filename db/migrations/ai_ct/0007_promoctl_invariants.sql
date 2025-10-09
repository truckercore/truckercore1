begin;

-- Invariants and guards for rollout control-plane

-- 1) ai_rollouts (model_id-based) — canary pct monotonic and finish guard
create or replace function ai_rollouts_guard()
returns trigger language plpgsql as $$
begin
  -- Monotonic canary percentage when staying in canary
  if tg_op = 'UPDATE' and new.strategy = 'canary' and old.strategy = 'canary'
     and old.canary_pct is not null and new.canary_pct is not null
     and new.canary_pct < old.canary_pct then
    raise exception 'canary_pct must be monotonic increasing';
  end if;
  return new;
end$$;

drop trigger if exists trg_ai_rollouts_guard on ai_rollouts;
create trigger trg_ai_rollouts_guard
before update on ai_rollouts
for each row execute function ai_rollouts_guard();

create or replace function ai_finish_guard()
returns trigger language plpgsql as $$
begin
  -- Finishing canary must promote the current candidate to active
  if tg_op = 'UPDATE' and old.strategy = 'canary' and new.strategy = 'single'
     and (old.candidate_version_id is distinct from new.active_version_id) then
    raise exception 'finish must promote current candidate to active';
  end if;
  return new;
end$$;

drop trigger if exists trg_ai_finish_guard on ai_rollouts;
create trigger trg_ai_finish_guard
before update on ai_rollouts
for each row execute function ai_finish_guard();

-- 2) ai_model_rollouts (model_key-based) — range + monotonic + finish guard tied to serving table
alter table ai_model_rollouts
  add constraint if not exists chk_ai_model_rollouts_pct_range
  check (pct between 1 and 100);

create or replace function ai_model_rollouts_guard()
returns trigger language plpgsql as $$
begin
  if tg_op = 'UPDATE' and new.status = 'canary' and old.status = 'canary'
     and new.pct < old.pct then
    raise exception 'canary pct must be monotonic increasing';
  end if;
  return new;
end$$;

drop trigger if exists trg_ai_model_rollouts_guard on ai_model_rollouts;
create trigger trg_ai_model_rollouts_guard
before update on ai_model_rollouts
for each row execute function ai_model_rollouts_guard();

create or replace function ai_model_finish_guard()
returns trigger language plpgsql as $$
declare live text;
begin
  if tg_op = 'UPDATE' and old.status = 'canary' and new.status = 'closed' then
    select live_version_id into live from ai_model_serving where model_key = old.model_key;
    if live is null or live is distinct from old.candidate_version_id then
      raise exception 'finish must promote current candidate (serving.live_version_id mismatch)';
    end if;
  end if;
  return new;
end$$;

drop trigger if exists trg_ai_model_finish_guard on ai_model_rollouts;
create trigger trg_ai_model_finish_guard
before update on ai_model_rollouts
for each row execute function ai_model_finish_guard();

commit;
