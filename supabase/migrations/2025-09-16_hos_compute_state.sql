-- 2025-09-16_hos_compute_state.sql
-- HOS helpers: status normalization view + pragmatic split-sleeper and 34h reset state computation.
-- Notes:
-- - Consumers should select from hos_logs_std to get normalized statuses.
-- - hos_compute_state implements a practical heuristic:
--     * Split-sleeper pause when a continuous off/sleeper block >= 7 hours ends at/before now().
--     * 34-hour reset: if any continuous off/sleeper >= 34 hours since last duty, cycle_start is reset to that block's end.
-- - For full FMCSA split logic (8/2, exclusions), extend by finding both qualifying segments and recomputing the 14-hour boundary.

set search_path = public;

-- 1) Status normalization view
create or replace view public.hos_logs_std as
select
  h.id,
  h.org_id,
  h.driver_user_id,
  h.start_time as started_at,
  h.end_time   as ended_at,
  -- Normalize synonyms: 'on' => 'on_duty', 'off' => 'off_duty'
  case
    when h.status = 'on' then 'on_duty'
    when h.status = 'off' then 'off_duty'
    else h.status
  end as status,
  h.source,
  h.eld_provider,
  h.created_at
from public.hos_logs h;

-- Ensure security invoker on the view so caller's RLS applies if exposed
alter view public.hos_logs_std set (security_invoker = on);

comment on view public.hos_logs_std is 'Normalized HOS logs view. Maps on/off to on_duty/off_duty. Prefer this view for all HOS consumers.';

-- 2) Covering index to speed up high-frequency per-driver queries
-- Existing idx_hos_driver_time(driver_user_id, start_time desc) remains useful.
create index if not exists idx_hos_driver_time_status on public.hos_logs (driver_user_id, start_time desc, end_time desc, status);

-- 3) Helper to compute continuous off/sleeper islands ending <= p_at
-- and evaluate split-sleeper (>= 7h) and reset (>= 34h).
create or replace function public.hos_compute_state(
  p_driver_user_id uuid,
  p_at timestamptz default now(),
  p_cycle text default '70/8'
)
returns table (
  driver_user_id uuid,
  at timestamptz,
  current_status text,
  effective_shift_start timestamptz,
  cycle_start timestamptz,
  split_sleeper_applied boolean,
  reset_34h_applied boolean
)
language plpgsql
stable
security definer
as $$
declare
  v_current_status text;
  v_eff_shift_start timestamptz := null;
  v_cycle_start timestamptz := null;
  v_split boolean := false;
  v_reset boolean := false;
  v_last_duty_time timestamptz := null;
  v_cycle_window interval := case when p_cycle ~ '^70/8$' then interval '8 days' else interval '7 days' end; -- default fallback
begin
  -- Determine current status at p_at (if any segment overlaps p_at)
  select l.status into v_current_status
  from public.hos_logs_std l
  where l.driver_user_id = p_driver_user_id
    and l.started_at <= p_at
    and l.ended_at > p_at
  order by l.started_at desc
  limit 1;

  if v_current_status is null then
    -- If no overlapping segment, use last segment before p_at
    select l.status into v_current_status
    from public.hos_logs_std l
    where l.driver_user_id = p_driver_user_id
      and l.started_at < p_at
    order by l.started_at desc
    limit 1;
  end if;

  -- Find the most recent on-duty/driving segment start before p_at (last duty time)
  select l.started_at into v_last_duty_time
  from public.hos_logs_std l
  where l.driver_user_id = p_driver_user_id
    and l.started_at < p_at
    and l.status in ('driving','on_duty')
  order by l.started_at desc
  limit 1;

  -- Compute the most recent continuous off/sleeper block that ended at/before p_at
  -- Start from the latest off/sleeper segment that ends <= p_at and walk back while contiguous
  with recursive last_off as (
    select l.started_at, l.ended_at
    from public.hos_logs_std l
    where l.driver_user_id = p_driver_user_id
      and l.ended_at <= p_at
      and l.status in ('off_duty','sleeper')
    order by l.ended_at desc
    limit 1
  ), island as (
    select l.started_at, l.ended_at
    from last_off l
    union all
    select p.started_at, p.ended_at
    from public.hos_logs_std p
    join island i on p.ended_at = i.started_at
    where p.driver_user_id = p_driver_user_id
      and p.status in ('off_duty','sleeper')
  )
  select min(started_at) as block_start, max(ended_at) as block_end
  into strict v_eff_shift_start, v_cycle_start -- temporary reuse; we'll overwrite properly below
  from island;

  -- Now v_eff_shift_start temporarily holds block_start, and v_cycle_start holds block_end.
  -- Determine durations
  if v_cycle_start is not null and v_eff_shift_start is not null then
    if (v_cycle_start - v_eff_shift_start) >= interval '7 hours' then
      v_split := true;
    end if;
    if (v_cycle_start - v_eff_shift_start) >= interval '34 hours' then
      v_reset := true;
    end if;
  end if;

  -- Effective shift start: if split applied, the 14-hour boundary pauses at block_end
  if v_split then
    v_eff_shift_start := v_cycle_start; -- set to block_end
  else
    -- else use last transition from off/sleeper into duty before p_at, fallback to last duty start
    select l.started_at into v_eff_shift_start
    from public.hos_logs_std l
    where l.driver_user_id = p_driver_user_id
      and l.started_at < p_at
      and l.status in ('driving','on_duty')
    order by l.started_at desc
    limit 1;
  end if;

  -- Cycle start: if a 34h reset occurred since last duty, set to block_end of that reset block
  if v_reset then
    -- Walk further back to locate any off/sleeper island >= 34h since last duty
    with recursive seeds as (
      select l.started_at, l.ended_at
      from public.hos_logs_std l
      where l.driver_user_id = p_driver_user_id
        and l.ended_at <= p_at
        and l.status in ('off_duty','sleeper')
      order by l.ended_at desc
      limit 1
    ), islands as (
      select s.started_at, s.ended_at
      from seeds s
      union all
      select p.started_at, p.ended_at
      from public.hos_logs_std p
      join islands i on p.ended_at = i.started_at
      where p.driver_user_id = p_driver_user_id
        and p.status in ('off_duty','sleeper')
    )
    select max(ended_at)
    into v_cycle_start
    from (
      select min(started_at) as s, max(ended_at) as e
      from islands
    ) x
    where (x.e - x.s) >= interval '34 hours';
  else
    -- Default cycle start approximation: last duty time constrained by cycle window
    select max(l.started_at)
    into v_cycle_start
    from public.hos_logs_std l
    where l.driver_user_id = p_driver_user_id
      and l.status in ('driving','on_duty')
      and l.started_at >= (p_at - v_cycle_window);
  end if;

  return query select
    p_driver_user_id as driver_user_id,
    p_at as at,
    coalesce(v_current_status, 'unknown') as current_status,
    v_eff_shift_start as effective_shift_start,
    v_cycle_start as cycle_start,
    v_split as split_sleeper_applied,
    coalesce(v_reset, false) as reset_34h_applied;
end;
$$;

-- Narrow grants: read-only compute function can be available to authenticated (optionally anon)
revoke all on function public.hos_compute_state(uuid, timestamptz, text) from public;
grant execute on function public.hos_compute_state(uuid, timestamptz, text) to authenticated;
-- If you want public read for demos, uncomment the next line.
-- grant execute on function public.hos_compute_state(uuid, timestamptz, text) to anon;

comment on function public.hos_compute_state(uuid, timestamptz, text) is 'Compute HOS state with normalized statuses, pragmatic split-sleeper pause (>=7h), and optional 34h reset. For full FMCSA split logic, extend to pair qualifying segments.';
