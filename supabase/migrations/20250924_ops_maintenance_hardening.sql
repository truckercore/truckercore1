-- 20250924_ops_maintenance_hardening.sql
-- Purpose: Hardening helpers for nightly maintenance: advisory lock, replica check,
--          next-partition presence probe. Safe to re-run.

set statement_timeout = '2min';
set lock_timeout = '10s';
begin;

-- Single-runner mutex helpers (fixed key). Returns whether lock was acquired.
create or replace function public.tc_advisory_lock()
returns boolean
language sql
security definer
as $$
  select pg_try_advisory_lock(987654321);
$$;

create or replace function public.tc_advisory_unlock()
returns void
language sql
security definer
as $$
  select pg_advisory_unlock(987654321);
$$;

-- Replica detector (skip VACUUM/ANALYZE when true)
create or replace function public.tc_is_replica()
returns boolean
language sql
security definer
as $$
  select pg_is_in_recovery();
$$;

-- Check if next month's edge_request_log partition exists
create or replace function public.tc_next_month_partition_present()
returns boolean
language plpgsql
security definer
as $$
declare
  start_of_next date := (date_trunc('month', now()) + interval '1 month')::date;
  part_name     text := format('edge_request_log_%s', to_char(start_of_next, 'YYYY_MM'));
  present boolean := false;
begin
  select exists (
    select 1 from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = part_name
  ) into present;
  return present;
end;
$$;

-- Lock down to service role only where appropriate
revoke all on function public.tc_advisory_lock()  from public, anon, authenticated;
revoke all on function public.tc_advisory_unlock() from public, anon, authenticated;
revoke all on function public.tc_is_replica()      from public, anon, authenticated;
revoke all on function public.tc_next_month_partition_present() from public, anon, authenticated;

grant execute on function public.tc_advisory_lock()  to service_role;
grant execute on function public.tc_advisory_unlock() to service_role;
grant execute on function public.tc_is_replica()      to service_role;
grant execute on function public.tc_next_month_partition_present() to service_role;

commit;
reset statement_timeout;
reset lock_timeout;
