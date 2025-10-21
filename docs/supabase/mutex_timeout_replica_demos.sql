-- docs/supabase/mutex_timeout_replica_demos.sql
-- Postgres snippets: advisory lock (mutex), statement_timeout failure capture, replica-aware vacuum,
-- and partition gap auto-create smoke. Copy/paste in Supabase SQL editor as needed.

-- 1) Mutex sanity (advisory lock demo): acquire-and-skip pattern
DO $$
DECLARE got boolean;
BEGIN
  got := pg_try_advisory_lock(987654321); -- pick a stable bigint
  IF NOT got THEN
    RAISE NOTICE '[ops] another run is active, skipping';
    RETURN;
  END IF;

  -- simulate work
  PERFORM pg_sleep(2);
  RAISE NOTICE '[ops] work completed';

  -- always unlock
  PERFORM pg_advisory_unlock(987654321);
END $$;

-- 2) Timeout path (forced failure on a step) with log capture
DO $$
DECLARE v_prev text; v_ok boolean := true; v_err text := null;
BEGIN
  SELECT current_setting('statement_timeout', true) INTO v_prev;
  PERFORM set_config('statement_timeout','50ms', true);

  BEGIN
    -- example slow step
    PERFORM pg_sleep(0.2);
  EXCEPTION WHEN OTHERS THEN
    v_ok := false; v_err := SQLERRM;
  END;

  PERFORM set_config('statement_timeout', coalesce(v_prev,'0'), true);

  INSERT INTO public.ops_maintenance_log(task, ok, ran_at, details)
  VALUES ('nightly_maintenance', v_ok, now(),
          jsonb_build_object('steps', jsonb_build_array(
            jsonb_build_object('name','slow_step','ok',v_ok,'error',v_err,'ms',50)
          )));
END $$;

-- 3) Replica awareness (skip VACUUM on replicas)
DO $$
DECLARE is_replica boolean;
BEGIN
  SELECT pg_is_in_recovery() INTO is_replica;
  IF is_replica THEN
    INSERT INTO public.ops_maintenance_log(task, ok, ran_at, details)
    VALUES ('nightly_maintenance', true, now(), jsonb_build_object('note','replica mode, skipping vacuum'));
    RETURN;
  END IF;

  -- primary-only
  VACUUM ANALYZE public.edge_request_log;
END $$;

-- 4) Partition gap auto-create (+ index) smoke for next month
CREATE OR REPLACE FUNCTION public.ensure_next_month_edge_log_partition()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  y int := extract(year from (date_trunc('month', now()) + interval '1 month'))::int;
  m int := extract(month from (date_trunc('month', now()) + interval '1 month'))::int;
  part regclass;
  part_name text := format('edge_request_log_%s_%s', y, lpad(m::text,2,'0'));
  from_date date := date_trunc('month', now())::date + interval '1 month';
  to_date date := (date_trunc('month', now()) + interval '2 month')::date;
BEGIN
  SELECT to_regclass(part_name) INTO part;
  IF part IS NULL THEN
    EXECUTE format(
      'create table %I partition of public.edge_request_log for values from (%L) to (%L)',
      part_name, from_date::date, to_date::date
    );
    -- indexes
    EXECUTE format('create index if not exists %I_ts_idx on %I(ts desc)', part_name||'_ts', part_name);
    EXECUTE format('create index if not exists %I_op_ts_ms_idx on %I(op, ts desc, ms)', part_name||'_op_ts_ms', part_name);
    EXECUTE format('create index if not exists %I_org_ts_idx on %I(org_id, ts desc)', part_name||'_org_ts', part_name);
    EXECUTE format('create index if not exists %I_status_idx on %I(status)', part_name||'_status', part_name);
    -- optional breadcrumb
    INSERT INTO public.ops_maintenance_log(task, ok, ms, details)
    VALUES ('partition_create', true, 0, jsonb_build_object('table',part_name));
  END IF;
END $$;

-- Smoke call (idempotent)
SELECT public.ensure_next_month_edge_log_partition();
