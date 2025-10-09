-- 0013_si_attachments_extras.sql
-- Extras for safety_incidents attachments:
-- - Block legacy writes to file_url (trigger)
-- - Retention helper: purge_old_incidents(p_ttl_days int)
-- All statements are idempotent and safe to re-run.

begin;

-- Legacy write-block trigger function (file_url)
create or replace function public._block_legacy_file_url()
returns trigger
language plpgsql
as $$
begin
  -- Only act if the column actually exists on the row type
  -- If the column doesn't exist, this function should never be invoked (trigger is only created when column exists)
  if tg_op in ('INSERT','UPDATE') then
    if (new.file_url is distinct from coalesce(old.file_url, null)) then
      raise exception 'file_url is deprecated; write to attachments instead';
    end if;
  end if;
  return new;
end; $$;

-- Install trigger only if the legacy column exists
DO $$
BEGIN
  IF exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'safety_incidents' and column_name = 'file_url'
  ) THEN
    -- Drop then create to ensure the trigger is in place
    drop trigger if exists trg_block_legacy_file_url on public.safety_incidents;
    create trigger trg_block_legacy_file_url
    before insert or update on public.safety_incidents
    for each row execute function public._block_legacy_file_url();
  END IF;
END $$;

-- Retention helper: purge attachments for incidents older than N days
-- Returns the number of rows modified. Intentionally conservative: we do NOT delete incidents.
create or replace function public.purge_old_incidents(p_ttl_days int)
returns int
language plpgsql
security definer
as $$
declare
  v_cnt int := 0;
begin
  -- Guard: if table missing, or created_at column missing, no-op
  if to_regclass('public.safety_incidents') is null then
    return 0;
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='safety_incidents' and column_name='created_at'
  ) then
    -- No created_at; nothing to purge by age
    return 0;
  end if;

  -- Update rows older than the cutoff: clear attachments array
  update public.safety_incidents s
  set attachments = '[]'::jsonb
  where s.created_at < now() - (p_ttl_days || ' days')::interval
    and attachments is not null
    and attachments <> '[]'::jsonb;

  GET DIAGNOSTICS v_cnt = ROW_COUNT;

  -- Optional: emit a metric if a metrics_events table exists
  if to_regclass('public.metrics_events') is not null and coalesce(v_cnt,0) > 0 then
    begin
      insert into public.metrics_events(kind, props)
      values ('purge_delete', jsonb_build_object('count', v_cnt, 'cutoff_days', p_ttl_days));
    exception when others then
      -- ignore metrics failures
      null;
    end;
  end if;

  return v_cnt;
end $$;

-- Lock down purge function privileges (least privilege)
revoke all on function public.purge_old_incidents(int) from public;
grant execute on function public.purge_old_incidents(int) to service_role;

commit;
