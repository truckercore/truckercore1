-- docs/supabase/hos_adapter.sql
-- Ready-to-use adapter that exposes hos_remaining_drive_minutes(uuid) while allowing
-- you to switch the underlying implementation without changing validators.
--
-- Usage: psql -f docs/supabase/hos_adapter.sql (ensure it runs in the correct DB)
-- Adjust the referenced function name inside to match your real HOS backend.

-- Example: if you already have a function public.hos_minutes_remaining(p_driver uuid, p_tz text)
-- that returns a JSON like { drive_minutes: int, duty_minutes: int }, we can wrap it.

create or replace function public.hos_remaining_drive_minutes(p_driver uuid)
returns integer
language plpgsql
security definer
as $$
declare
  v_minutes integer := 0;
  v_resp jsonb;
begin
  -- Replace the call below with your real HOS function. Fallback to 0 if null/errors.
  -- Example backend function signature: hos_minutes_remaining(p_driver uuid, p_tz text)
  begin
    select coalesce((v_resp->>'drive_minutes')::int, 0)
      into v_minutes
    from (
      select public.hos_minutes_remaining(p_driver, 'UTC')::jsonb as v_resp
    ) s;
  exception when others then
    v_minutes := 0;
  end;

  return v_minutes;
end;
$$;

-- Helpful index (if you’ll look up validation audit by user/time frequently)
create index if not exists idx_validation_audit_user_time on public.validation_audit(user_id, created_at desc);
