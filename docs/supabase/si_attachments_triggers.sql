-- Optional validation and write-block triggers for safety_incidents.attachments

-- Shape enforcement trigger (only needed if you want runtime blocks in addition to CHECKs)
create or replace function public.fn_si_attachments_validate()
returns trigger
language plpgsql
as $$
declare v jsonb;
begin
  if new.attachments is null then
    raise exception 'attachments must be a JSON array' using errcode='22000';
  end if;
  if jsonb_typeof(new.attachments) <> 'array' then
    raise exception 'attachments must be a JSON array' using errcode='22000';
  end if;
  for v in select * from jsonb_array_elements(new.attachments) loop
    if jsonb_typeof(v) <> 'object' then
      raise exception 'attachments elements must be objects' using errcode='22000';
    end if;
    if (v ? 'url') is false or jsonb_typeof(v->'url') <> 'string' then
      raise exception 'attachments element missing url (string)' using errcode='22000';
    end if;
    if (v ? 'type') is false or jsonb_typeof(v->'type') <> 'string' then
      raise exception 'attachments element missing type (string)' using errcode='22000';
    end if;
    if (v ? 'metadata') and jsonb_typeof(v->'metadata') <> 'object' then
      raise exception 'attachments.metadata must be object when present' using errcode='22000';
    end if;
  end loop;
  return new;
end $$;

-- Enable (during soak)
-- drop trigger if exists trg_si_attachments_validate on public.safety_incidents;
-- create trigger trg_si_attachments_validate
-- before insert or update of attachments on public.safety_incidents
-- for each row execute function public.fn_si_attachments_validate();

-- Temporary write-block trigger for rollback safety (enable during soak; drop to unblock)
create or replace function public.fn_block_writes_temporarily()
returns trigger language plpgsql as $$
begin
  raise exception 'write-block active for safety_incidents during deploy' using errcode='55000';
end $$;

-- Enable (soak window):
-- create trigger trg_si_block_writes before insert or update on public.safety_incidents
-- for each statement execute function public.fn_block_writes_temporarily();

-- Disable:
-- drop trigger if exists trg_si_block_writes on public.safety_incidents;
