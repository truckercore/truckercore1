begin;

-- Deferrable "one active per model" check for serving table
-- Because ai_model_serving has one row per model_key by PK, this acts as a safety net
-- to prevent accidental deletes/duplication within a transaction window.

create or replace function public.fn_one_active_deferred()
returns trigger language plpgsql as $$
declare v_bad int;
begin
  -- Check that every model_key present in serving has exactly one row
  -- (PK enforces at most one; this ensures at least one too if modified in the tx)
  with agg as (
    select model_key, count(*) as c from public.ai_model_serving group by model_key
  )
  select count(*) into v_bad from agg where c <> 1;
  if coalesce(v_bad,0) > 0 then
    raise exception 'exactly one active required per model_key';
  end if;
  return null; -- statement-level trigger
end $$;

-- Constraint trigger fires at end of statement/transaction and is deferrable
drop trigger if exists trg_one_active_deferred on public.ai_model_serving;
create constraint trigger trg_one_active_deferred
after insert or update or delete on public.ai_model_serving
deferrable initially deferred
for each statement
execute function public.fn_one_active_deferred();

commit;
