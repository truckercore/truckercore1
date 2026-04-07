-- Edge log retention & partition verification (self-asserting)
-- Parameterized by RETENTION_DAYS environment variable passed by CLI
-- Fallback to 30 if not provided

-- Bootstrap a session GUC from env or default to 30
DO $$
DECLARE
  v_days INT := COALESCE(NULLIF(current_setting('app.retention_days', true), '')::INT, NULL);
  v_env  TEXT := current_setting('RETENTION_DAYS', true);
BEGIN
  IF v_days IS NULL THEN
    BEGIN
      v_days := GREATEST(1, LEAST(365, COALESCE(NULLIF(v_env,'')::INT, 30)));
    EXCEPTION WHEN OTHERS THEN
      v_days := 30;
    END;
    PERFORM set_config('app.retention_days', v_days::TEXT, FALSE);
  END IF;
END$$;

-- Assertions and summary -------------------------------------------------------
WITH cfg AS (
  SELECT current_setting('app.retention_days')::INT AS retention_days
),
oldest AS (
  SELECT MIN(ts) AS min_ts, MAX(ts) AS max_ts FROM public.edge_request_log
),
breaches AS (
  SELECT COUNT(*) AS rows_beyond
  FROM public.edge_request_log, cfg
  WHERE ts < now() - (SELECT retention_days FROM cfg) * INTERVAL '1 day'
),
next_month_partition AS (
  SELECT 1 FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relkind = 'r'
    AND c.relname = to_char(now() + interval '1 month', '"edge_request_log_"YYYY_MM')
)
SELECT
  (SELECT retention_days FROM cfg) AS retention_days,
  (SELECT min_ts FROM oldest) AS oldest_row_ts,
  (SELECT max_ts FROM oldest) AS newest_row_ts,
  (SELECT rows_beyond FROM breaches) AS rows_beyond_retention,
  COALESCE((SELECT 1 FROM next_month_partition), 0) AS has_next_month_partition;

DO $$
DECLARE
  v_days INT := current_setting('app.retention_days')::INT;
  v_beyond BIGINT;
  v_next INT;
  v_oldest TIMESTAMPTZ;
BEGIN
  SELECT COUNT(*) INTO v_beyond FROM public.edge_request_log WHERE ts < now() - v_days * INTERVAL '1 day';
  SELECT COALESCE((
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname='public'
      AND c.relkind='r'
      AND c.relname = to_char(now() + interval '1 month', '"edge_request_log_"YYYY_MM')
  ), 0) INTO v_next;
  SELECT MIN(ts) INTO v_oldest FROM public.edge_request_log;

  IF v_beyond > 0 THEN
    RAISE EXCEPTION 'Retention breach: % rows older than % days', v_beyond, v_days;
  END IF;

  IF v_next = 0 THEN
    RAISE EXCEPTION 'Missing next-month partition for edge_request_log';
  END IF;

  IF v_oldest IS NOT NULL AND v_oldest < now() - v_days * INTERVAL '1 day' THEN
    RAISE EXCEPTION 'Oldest row is beyond retention window: %', v_oldest;
  END IF;
END $$;
