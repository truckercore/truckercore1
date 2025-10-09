-- 1015_hos_summarize_daily.sql
-- Adds summarize_hos_daily RPC with secure defaults and fully-qualified refs.

create or replace function public.summarize_hos_daily(p_driver uuid, p_day date)
returns table(driving_hours numeric, on_duty_hours numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Sum hours within the [p_day, p_day+1) window, clamped to each log segment.
  return query
  select
    coalesce(
      sum(
        extract(epoch from (
          least(hl.end_time, ((p_day + 1)::timestamptz)) -
          greatest(hl.start_time, (p_day::timestamptz))
        ))
      ) filter (where hl.status = 'driving') / 3600.0,
      0
    ),
    coalesce(
      sum(
        extract(epoch from (
          least(hl.end_time, ((p_day + 1)::timestamptz)) -
          greatest(hl.start_time, (p_day::timestamptz))
        ))
      ) filter (where hl.status = 'on') / 3600.0,
      0
    )
  from public.hos_logs hl
  where hl.driver_user_id = p_driver
    and hl.start_time < ((p_day + 1)::timestamptz)
    and hl.end_time   >  (p_day::timestamptz);
end;
$$;

-- Least-privilege: do not expose to PUBLIC.
revoke all on function public.summarize_hos_daily(uuid, date) from public;
-- Intended role: allow authenticated users (RLS on hos_logs still applies)
grant execute on function public.summarize_hos_daily(uuid, date) to authenticated;
