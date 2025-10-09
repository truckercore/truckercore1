-- 1007_sli_burn_rates.sql
-- Purpose: Canary burn-rate alerts based on 1h/6h windows against SLI targets.
-- Defensive: creates empty views if required sources are missing.

-- Helper views for short windows (depend on sli_24h view)
DO $$
BEGIN
  IF to_regclass('public.sli_24h') IS NOT NULL THEN
    EXECUTE $$
      CREATE OR REPLACE VIEW public.sli_1h AS
      SELECT kind,
             date_trunc('hour', now()) - interval '1 hour' AS window_start,
             now() AS window_end,
             sum(good) AS good,
             sum(total) AS total
      FROM public.sli_24h
      WHERE window_end >= now() - interval '1 hour'
      GROUP BY kind;
    $$;

    EXECUTE $$
      CREATE OR REPLACE VIEW public.sli_6h AS
      SELECT kind,
             now() - interval '6 hours' AS window_start,
             now() AS window_end,
             sum(good) AS good,
             sum(total) AS total
      FROM public.sli_24h
      WHERE window_end >= now() - interval '6 hours'
      GROUP BY kind;
    $$;
  ELSE
    -- Fallback empty views with compatible schema
    EXECUTE $$
      CREATE OR REPLACE VIEW public.sli_1h AS
      SELECT kind::text, now() - interval '1 hour' AS window_start, now() AS window_end,
             NULL::int AS good, NULL::int AS total
      FROM (SELECT NULL::text AS kind) s WHERE 1=0;
    $$;

    EXECUTE $$
      CREATE OR REPLACE VIEW public.sli_6h AS
      SELECT kind::text, now() - interval '6 hours' AS window_start, now() AS window_end,
             NULL::int AS good, NULL::int AS total
      FROM (SELECT NULL::text AS kind) s WHERE 1=0;
    $$;
  END IF;
END$$;

-- Targets table (if not present)
CREATE TABLE IF NOT EXISTS public.sli_targets (
  kind text PRIMARY KEY,
  target_pct numeric NOT NULL -- e.g., 99.9
);

-- Burn alerts sink (for audits/graphing)
CREATE TABLE IF NOT EXISTS public.slo_burn_alerts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  kind text NOT NULL,
  window text NOT NULL CHECK (window IN ('1h','6h')),
  burn_rate numeric NOT NULL,
  target_pct numeric NOT NULL,
  good int NOT NULL,
  total int NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Error budget burn-rate check; also emits to alert_outbox when available
CREATE OR REPLACE FUNCTION public.check_slo_burn_rates()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=public
AS $$
DECLARE
  r record;
  target numeric;
  error_budget numeric;
  err_rate numeric;
  burn_rate numeric;
  br1 numeric := 2.0;  -- threshold for 1h window
  br6 numeric := 1.0;  -- threshold for 6h window
  has_enqueue boolean := (to_regclass('public.alert_outbox') IS NOT NULL);
BEGIN
  -- 1h window
  FOR r IN SELECT s.kind, s.good, s.total FROM public.sli_1h s LOOP
    SELECT target_pct INTO target FROM public.sli_targets WHERE kind = r.kind;
    IF target IS NULL OR coalesce(r.total,0) = 0 THEN CONTINUE; END IF;
    error_budget := 1 - (target / 100.0);
    err_rate := greatest(0, 1 - (r.good::numeric / r.total::numeric));
    IF error_budget <= 0 THEN CONTINUE; END IF;
    burn_rate := err_rate / error_budget;
    IF burn_rate >= br1 THEN
      INSERT INTO public.slo_burn_alerts(kind, window, burn_rate, target_pct, good, total)
      VALUES (r.kind, '1h', burn_rate, target, coalesce(r.good,0), coalesce(r.total,0));
      IF has_enqueue THEN
        PERFORM public.enqueue_alert_if_not_muted(
          'canary_burn_rate',
          jsonb_build_object(
            'window','1h','kind',r.kind,
            'burn_rate', burn_rate,
            'target_pct', target,
            'good', coalesce(r.good,0),
            'total', coalesce(r.total,0)
          )
        );
      END IF;
    END IF;
  END LOOP;

  -- 6h window
  FOR r IN SELECT s.kind, s.good, s.total FROM public.sli_6h s LOOP
    SELECT target_pct INTO target FROM public.sli_targets WHERE kind = r.kind;
    IF target IS NULL OR coalesce(r.total,0) = 0 THEN CONTINUE; END IF;
    error_budget := 1 - (target / 100.0);
    err_rate := greatest(0, 1 - (r.good::numeric / r.total::numeric));
    IF error_budget <= 0 THEN CONTINUE; END IF;
    burn_rate := err_rate / error_budget;
    IF burn_rate >= br6 THEN
      INSERT INTO public.slo_burn_alerts(kind, window, burn_rate, target_pct, good, total)
      VALUES (r.kind, '6h', burn_rate, target, coalesce(r.good,0), coalesce(r.total,0));
      IF has_enqueue THEN
        PERFORM public.enqueue_alert_if_not_muted(
          'canary_burn_rate',
          jsonb_build_object(
            'window','6h','kind',r.kind,
            'burn_rate', burn_rate,
            'target_pct', target,
            'good', coalesce(r.good,0),
            'total', coalesce(r.total,0)
          )
        );
      END IF;
    END IF;
  END LOOP;
END;
$$;

-- (Optional) Cron scheduling (documentation; set via Supabase Scheduled Tasks or pg_cron)
-- Every 10 minutes: select public.check_slo_burn_rates();
