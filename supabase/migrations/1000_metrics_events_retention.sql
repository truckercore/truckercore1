-- 1000_metrics_events_retention.sql
-- Monitor metrics_events volumes and add basic retention helpers

-- Guard: ensure table exists (some environments may not include metrics_events)
DO $$ BEGIN
  IF to_regclass('public.metrics_events') IS NULL THEN
    -- minimal schema (align to common superset); adjust if your project already created it elsewhere
    CREATE TABLE IF NOT EXISTS public.metrics_events (
      id bigserial PRIMARY KEY,
      org_id uuid NULL,
      event_code text NULL,
      kind text NULL,
      entity_kind text NULL,
      entity_id text NULL,
      prev_state jsonb NULL,
      new_state jsonb NULL,
      tags jsonb NULL,
      at timestamptz NOT NULL DEFAULT now(),
      created_at timestamptz NOT NULL DEFAULT now()
    );
    CREATE INDEX IF NOT EXISTS idx_metrics_events_at ON public.metrics_events(at DESC);
    CREATE INDEX IF NOT EXISTS idx_metrics_events_code_at ON public.metrics_events(event_code, at DESC);
    CREATE INDEX IF NOT EXISTS idx_metrics_events_org_at ON public.metrics_events(org_id, at DESC);
    ALTER TABLE public.metrics_events ENABLE ROW LEVEL SECURITY;
  END IF;
END $$;

-- Simple 24h volume view by event_code (and org when present)
CREATE OR REPLACE VIEW public.ops_metrics_events_24h AS
SELECT
  coalesce(event_code, kind, 'unknown') AS code,
  count(*) AS cnt,
  count(*) FILTER (WHERE org_id IS NOT NULL) AS cnt_with_org,
  min(at) AS first_seen,
  max(at) AS last_seen
FROM public.metrics_events
WHERE at >= now() - interval '24 hours'
GROUP BY 1
ORDER BY cnt DESC;

-- Retention helper: purge rows older than N days (default 90)
CREATE OR REPLACE FUNCTION public.purge_metrics_events(p_days int DEFAULT 90)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count int;
BEGIN
  IF to_regclass('public.metrics_events') IS NULL THEN
    RETURN 0;
  END IF;
  DELETE FROM public.metrics_events
  WHERE at < now() - (p_days || ' days')::interval;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

-- Optional: daily cron suggestion (documentation only)
-- Schedule: Daily 04:10 UTC → select public.purge_metrics_events(90);
