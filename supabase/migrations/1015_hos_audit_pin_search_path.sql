-- 1015_hos_audit_pin_search_path.sql
-- Purpose: Pin search_path and fully-qualify objects for HOS and audit trigger functions.
-- Applies remediation pattern: language plpgsql security definer set search_path=public
-- and fully-qualified references (public.*). Avoids dynamic SQL.

-- 1) HOS split pair validator (placeholder logic; adjust to real split rules as needed)
create or replace function public.hos_valid_split_pair(
  p_driver uuid,
  p_start timestamptz,
  p_end timestamptz
) returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  ok boolean := false;
begin
  -- Example validation: confirm logs exist for the driver fully within the window.
  -- Replace/add predicates to enforce real split-sleeper rules if available in schema.
  select exists (
    select 1
    from public.hos_logs hl
    where hl.driver_user_id = p_driver
      and hl.start_time >= p_start
      and hl.end_time <= p_end
  ) into ok;

  return coalesce(ok, false);
end;
$$;

-- 2) Audit trigger: normalize NEW row before insert into audit table(s)
-- This is defined generically; bind to your audit table with a BEFORE INSERT trigger.
create or replace function public.fn_audit_log_before_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Ensure created_at has a value
  if new.created_at is null then
    new.created_at := now();
  end if;

  -- Optional: clamp error text length if present (avoid oversized rows)
  if new.error is not null then
    new.error := left(new.error, 2000);
  end if;

  -- Add other sanitizations as needed (all references must be fully-qualified if selecting other tables)
  return new;
end;
$$;

-- 3) Post-fix hardening: least-privilege grants
revoke all on function public.hos_valid_split_pair(uuid, timestamptz, timestamptz) from public;
grant execute on function public.hos_valid_split_pair(uuid, timestamptz, timestamptz) to authenticated, service_role;

revoke all on function public.fn_audit_log_before_insert() from public;
grant execute on function public.fn_audit_log_before_insert() to service_role;
