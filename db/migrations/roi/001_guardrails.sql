begin;

-- prevent negative $ and absurd values (>$100k per event)
alter table ai_roi_events
  add constraint if not exists chk_roi_amount_nonneg check (amount_cents >= 0),
  add constraint if not exists chk_roi_amount_reasonable check (amount_cents <= 10000000);

-- rationale must not be empty for AI-sourced events
alter table ai_roi_events
  add column if not exists rationale_min_keys text[] default '{}'::text[];

create or replace function roi_rationale_guard() returns trigger
language plpgsql as $$
begin
  if new.rationale is null or new.rationale = '{}'::jsonb then
    raise exception 'rationale required';
  end if;
  if array_length(new.rationale_min_keys,1) is not null then
    -- Ensure all required keys exist in rationale
    if exists (
      select 1
      from unnest(new.rationale_min_keys) as k
      where not (new.rationale ? k)
    ) then
      raise exception 'rationale missing required keys: %', new.rationale_min_keys;
    end if;
  end if;
  return new;
end$$;

drop trigger if exists trg_roi_rationale on ai_roi_events;
create trigger trg_roi_rationale
before insert on ai_roi_events
for each row execute function roi_rationale_guard();

commit;
