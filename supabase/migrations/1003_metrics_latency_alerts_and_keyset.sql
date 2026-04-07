-- 1003_metrics_latency_alerts_and_keyset.sql
-- Purpose: Add p95 latency alerting from metrics_events, thresholds table,
--          and safe keyset pagination RPCs with guards.
-- This migration is idempotent and defensive across environments.

-- 1) View: metrics_events_p95_24h (compute p95 latency per kind in last 24h)
--    Prefer props->>'ms' if column exists; else try new_state->>'ms'; else return empty.
DO $$
DECLARE
  has_props boolean;
  has_new_state boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema='public' AND table_name='metrics_events' AND column_name='props'
  ) INTO has_props;
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema='public' AND table_name='metrics_events' AND column_name='new_state'
  ) INTO has_new_state;

  IF has_props THEN
    EXECUTE $$
      CREATE OR REPLACE VIEW public.metrics_events_p95_24h AS
      SELECT
        kind,
        percentile_disc(0.95) WITHIN GROUP (ORDER BY (props->>'ms')::numeric) AS p95_ms
      FROM public.metrics_events
      WHERE props ? 'ms'
        AND created_at >= now() - interval '24 hours'
      GROUP BY kind;
    $$;
  ELSIF has_new_state THEN
    EXECUTE $$
      CREATE OR REPLACE VIEW public.metrics_events_p95_24h AS
      SELECT
        kind,
        percentile_disc(0.95) WITHIN GROUP (ORDER BY (new_state->>'ms')::numeric) AS p95_ms
      FROM public.metrics_events
      WHERE (new_state ? 'ms')
        AND created_at >= now() - interval '24 hours'
      GROUP BY kind;
    $$;
  ELSE
    -- Fallback placeholder: compatible columns, no rows
    EXECUTE $$
      CREATE OR REPLACE VIEW public.metrics_events_p95_24h AS
      SELECT kind::text, NULL::numeric AS p95_ms
      FROM (SELECT NULL::text AS kind) s
      WHERE 1=0;
    $$;
  END IF;
END$$;

-- 2) Thresholds config for metrics p95 alerts
CREATE TABLE IF NOT EXISTS public.metrics_alert_thresholds (
  kind text PRIMARY KEY,
  p95_ms_threshold int NOT NULL
);

-- Seed or update example threshold(s)
INSERT INTO public.metrics_alert_thresholds(kind, p95_ms_threshold) VALUES
  ('analytics_page_load', 5000)
ON CONFLICT (kind) DO UPDATE SET p95_ms_threshold = EXCLUDED.p95_ms_threshold;

-- 3) Procedure: check and emit alerts into alerts_events on threshold breach
-- Requires: public.alerts_events table (already present in repo migrations)
CREATE OR REPLACE FUNCTION public.check_latency_p95_and_alert()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=public
AS $$
DECLARE
  r RECORD;
  th INT;
BEGIN
  FOR r IN
    SELECT p.kind, p.p95_ms
    FROM public.metrics_events_p95_24h p
    JOIN public.metrics_alert_thresholds t ON t.kind = p.kind
    WHERE p.p95_ms > t.p95_ms_threshold
  LOOP
    SELECT p95_ms_threshold INTO th FROM public.metrics_alert_thresholds WHERE kind = r.kind;
    INSERT INTO public.alerts_events (org_id, severity, code, payload)
    VALUES (
      '00000000-0000-0000-0000-000000000000'::uuid,
      'warning',
      'latency_p95_breach',
      jsonb_build_object(
        'kind', r.kind,
        'p95_ms', r.p95_ms,
        'threshold_ms', th,
        'window', '24h',
        'at', now()
      )
    );
  END LOOP;
END;
$$;

-- 4) Keyset pagination RPCs (defensive: only run dynamic SQL when underlying views exist)
-- 4.1 Lane ROI keyset
CREATE SCHEMA IF NOT EXISTS api;
CREATE OR REPLACE FUNCTION api.list_lane_roi_keyset(
  p_limit int,
  p_cursor_profit numeric DEFAULT NULL,
  p_cursor_id bigint DEFAULT NULL
)
RETURNS SETOF RECORD
LANGUAGE plpgsql STABLE
AS $$
DECLARE
  v_exists boolean;
  sql text;
BEGIN
  SELECT to_regclass('public.v_lane_roi_and_detention') IS NOT NULL INTO v_exists;
  IF NOT v_exists THEN
    RETURN; -- empty set
  END IF;
  sql := 'SELECT * FROM public.v_lane_roi_and_detention
          WHERE ($1 IS NULL OR (profit_usd < $1) OR (profit_usd = $1 AND id < $2))
          ORDER BY profit_usd DESC, id DESC
          LIMIT GREATEST(1, LEAST($3, 200))';
  RETURN QUERY EXECUTE sql USING p_cursor_profit, p_cursor_id, p_limit;
END;
$$;

-- Provide a named composite type for better client ergonomics if view exists
DO $$ BEGIN
  IF to_regclass('public.v_lane_roi_and_detention') IS NOT NULL THEN
    -- Ensure function signature with concrete return type exists (SQL functions require known type)
    -- Create a wrapper with concrete type when view exists
    EXECUTE $$
      CREATE OR REPLACE FUNCTION api.list_lane_roi_keyset_concrete(
        p_limit int,
        p_cursor_profit numeric DEFAULT NULL,
        p_cursor_id bigint DEFAULT NULL
      )
      RETURNS SETOF public.v_lane_roi_and_detention
      LANGUAGE sql STABLE AS $$
        SELECT * FROM public.v_lane_roi_and_detention
        WHERE (
          p_cursor_profit IS NULL
          OR (profit_usd < p_cursor_profit)
          OR (profit_usd = p_cursor_profit AND id < p_cursor_id)
        )
        ORDER BY profit_usd DESC, id DESC
        LIMIT GREATEST(1, LEAST(p_limit, 200));
      $$;
    $$;
  END IF;
END $$;

-- 4.2 Detention facilities keyset
CREATE OR REPLACE FUNCTION api.list_facility_detention_keyset(
  p_limit int,
  p_cursor_avg_minutes numeric DEFAULT NULL,
  p_cursor_id bigint DEFAULT NULL
)
RETURNS SETOF RECORD
LANGUAGE plpgsql STABLE
AS $$
DECLARE
  v_exists boolean;
  sql text;
BEGIN
  SELECT to_regclass('public.v_detention_by_facility') IS NOT NULL INTO v_exists;
  IF NOT v_exists THEN
    RETURN; -- empty set
  END IF;
  sql := 'SELECT * FROM public.v_detention_by_facility
          WHERE ($1 IS NULL OR (avg_minutes < $1) OR (avg_minutes = $1 AND id < $2))
          ORDER BY avg_minutes DESC, id DESC
          LIMIT GREATEST(1, LEAST($3, 200))';
  RETURN QUERY EXECUTE sql USING p_cursor_avg_minutes, p_cursor_id, p_limit;
END;
$$;

DO $$ BEGIN
  IF to_regclass('public.v_detention_by_facility') IS NOT NULL THEN
    EXECUTE $$
      CREATE OR REPLACE FUNCTION api.list_facility_detention_keyset_concrete(
        p_limit int,
        p_cursor_avg_minutes numeric DEFAULT NULL,
        p_cursor_id bigint DEFAULT NULL
      )
      RETURNS SETOF public.v_detention_by_facility
      LANGUAGE sql STABLE AS $$
        SELECT * FROM public.v_detention_by_facility
        WHERE (
          p_cursor_avg_minutes IS NULL
          OR (avg_minutes < p_cursor_avg_minutes)
          OR (avg_minutes = p_cursor_avg_minutes AND id < p_cursor_id)
        )
        ORDER BY avg_minutes DESC, id DESC
        LIMIT GREATEST(1, LEAST(p_limit, 200));
      $$;
    $$;
  END IF;
END $$;

-- 5) Notes: schedule daily via pg_cron or Supabase Scheduled Task
-- Example (pg_cron):
-- select cron.schedule('check_latency_p95_daily', '25 3 * * *', $$select public.check_latency_p95_and_alert();$$);
