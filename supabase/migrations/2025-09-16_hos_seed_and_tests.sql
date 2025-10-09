-- 2025-09-16_hos_seed_and_tests.sql
-- Seed example HOS data and add test assertions so hos_run_assertions() shows green immediately.
--
-- Contents
-- - hos_seed_examples(): idempotently seeds two drivers with canonical HOS timelines
--   * Case A: split-sleeper pause (>=7h off/sleeper block)
--   * Case B: 34-hour reset (>=34h off/sleeper block)
-- - hos_run_assertions(): executes hos_compute_state() at fixed times and validates expectations
--   Returns rows (name, ok, detail). All ok=true indicates green.
--
-- Prerequisites
-- - Tables from prior migrations: public.hos_logs
-- - Function: public.hos_compute_state(uuid, timestamptz, text)
--
-- Usage
--   select * from public.hos_run_assertions();
--   -- Optional: reseed alone
--   select public.hos_seed_examples();

set search_path = public;

-- Deterministic UUIDs for seed data (do not collide with normal users)
-- org:   00000000-0000-4000-8000-0000000000aa
-- drv A: 00000000-0000-4000-8000-000000000001  (split-sleeper test)
-- drv B: 00000000-0000-4000-8000-000000000002  (34h reset test)

create or replace function public.hos_seed_examples()
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  -- Clean existing seed rows
  delete from public.hos_logs
   where driver_user_id in (
     '00000000-0000-4000-8000-000000000001'::uuid,
     '00000000-0000-4000-8000-000000000002'::uuid
   );

  -- Case A (Split-sleeper) — Query point: 2025-09-16 20:45 UTC
  -- Timeline (UTC):
  --  2025-09-16 08:00 - 12:00 driving
  --  2025-09-16 12:00 - 19:30 off (7.5h)  => qualifies for split-sleeper pause
  --  2025-09-16 19:30 - 22:00 driving     => current status driving at 20:45
  insert into public.hos_logs(org_id, driver_user_id, start_time, end_time, status, source)
  values
    ('00000000-0000-4000-8000-0000000000aa', '00000000-0000-4000-8000-000000000001',
      timestamptz '2025-09-16 08:00:00+00', timestamptz '2025-09-16 12:00:00+00', 'driving', 'manual'),
    ('00000000-0000-4000-8000-0000000000aa', '00000000-0000-4000-8000-000000000001',
      timestamptz '2025-09-16 12:00:00+00', timestamptz '2025-09-16 19:30:00+00', 'off', 'manual'),
    ('00000000-0000-4000-8000-0000000000aa', '00000000-0000-4000-8000-000000000001',
      timestamptz '2025-09-16 19:30:00+00', timestamptz '2025-09-16 22:00:00+00', 'driving', 'manual');

  -- Case B (34-hour reset) — Query point: 2025-09-15 12:30 UTC
  -- Timeline (UTC):
  --  2025-09-14 00:00 - 2025-09-15 10:30 off (34.5h) => triggers 34h reset
  --  2025-09-15 10:30 - 12:00 on
  --  2025-09-15 12:00 - 16:00 driving                 => current status driving at 12:30
  insert into public.hos_logs(org_id, driver_user_id, start_time, end_time, status, source)
  values
    ('00000000-0000-4000-8000-0000000000aa', '00000000-0000-4000-8000-000000000002',
      timestamptz '2025-09-14 00:00:00+00', timestamptz '2025-09-15 10:30:00+00', 'off', 'manual'),
    ('00000000-0000-4000-8000-0000000000aa', '00000000-0000-4000-8000-000000000002',
      timestamptz '2025-09-15 10:30:00+00', timestamptz '2025-09-15 12:00:00+00', 'on', 'manual'),
    ('00000000-0000-4000-8000-0000000000aa', '00000000-0000-4000-8000-000000000002',
      timestamptz '2025-09-15 12:00:00+00', timestamptz '2025-09-15 16:00:00+00', 'driving', 'manual');
end;
$$;

comment on function public.hos_seed_examples() is 'Seeds two deterministic drivers with canonical HOS timelines for split-sleeper and 34h reset tests.';

revoke all on function public.hos_seed_examples() from public;
grant execute on function public.hos_seed_examples() to authenticated, service_role;

-- Test runner: returns per-test results; all ok=true => green
create or replace function public.hos_run_assertions()
returns table(name text, ok boolean, detail text)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  drv_split uuid := '00000000-0000-4000-8000-000000000001'::uuid;
  drv_reset uuid := '00000000-0000-4000-8000-000000000002'::uuid;
  at_split timestamptz := timestamptz '2025-09-16 20:45:00+00';
  at_reset timestamptz := timestamptz '2025-09-15 12:30:00+00';
  r record;
  ok_all boolean := true;
  exp_ts timestamptz;
begin
  perform public.hos_seed_examples();

  -- Assertion A: split-sleeper pause applied, effective_shift_start = 2025-09-16 19:30Z, current=driving, cycle_start approx 19:30Z
  for r in select * from public.hos_compute_state(drv_split, at_split, '70/8') loop
    exp_ts := timestamptz '2025-09-16 19:30:00+00';
    return query select 'A_current_status'::text, (r.current_status = 'driving') as ok,
      format('expected driving, got %s', r.current_status);
    return query select 'A_split_applied'::text, (r.split_sleeper_applied is true) as ok,
      format('expected split=true, got %s', r.split_sleeper_applied);
    return query select 'A_eff_shift_start'::text, (r.effective_shift_start = exp_ts) as ok,
      format('expected %s, got %s', exp_ts, r.effective_shift_start);
    return query select 'A_cycle_start'::text, (r.cycle_start = exp_ts) as ok,
      format('expected %s, got %s', exp_ts, r.cycle_start);
    return query select 'A_reset_false'::text, (coalesce(r.reset_34h_applied,false) = false) as ok,
      format('expected reset=false, got %s', r.reset_34h_applied);
  end loop;

  -- Assertion B: 34h reset applied; cycle_start = 2025-09-15 10:30Z; split also true; eff_shift_start = 10:30Z
  for r in select * from public.hos_compute_state(drv_reset, at_reset, '70/8') loop
    exp_ts := timestamptz '2025-09-15 10:30:00+00';
    return query select 'B_current_status'::text, (r.current_status = 'driving') as ok,
      format('expected driving, got %s', r.current_status);
    return query select 'B_split_applied'::text, (r.split_sleeper_applied is true) as ok,
      format('expected split=true, got %s', r.split_sleeper_applied);
    return query select 'B_eff_shift_start'::text, (r.effective_shift_start = exp_ts) as ok,
      format('expected %s, got %s', exp_ts, r.effective_shift_start);
    return query select 'B_cycle_start_reset'::text, (r.reset_34h_applied is true and r.cycle_start = exp_ts) as ok,
      format('expected reset=true and cycle_start=%s, got reset=%s cycle_start=%s', exp_ts, r.reset_34h_applied, r.cycle_start);
  end loop;
end;
$$;

comment on function public.hos_run_assertions() is 'Runs two concrete HOS test cases against hos_compute_state() and reports per-assertion results.';

revoke all on function public.hos_run_assertions() from public;
grant execute on function public.hos_run_assertions() to authenticated, service_role;
