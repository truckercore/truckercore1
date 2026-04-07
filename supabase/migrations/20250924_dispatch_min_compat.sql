-- 20250924_dispatch_min_compat.sql
-- Purpose: Minimal compatibility migration to align dispatch core with spec
-- - Add explicit org-scoped RLS policies named per table (loads_rw, stops_rw, etc.)
-- - Ensure hot-path indexes exist
-- - Add a deduplicating status-change metrics trigger (event_code='status_change')
--
-- Idempotent and non-destructive. Keeps existing objects (e.g., generic org_rw and
-- existing load status trigger) intact while adding spec-aligned pieces.

-- ========== 1) RLS policies (org-scoped) ==========
DO $$
BEGIN
  -- loads
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='loads' AND policyname='loads_rw'
  ) THEN
    EXECUTE $$CREATE POLICY loads_rw ON public.loads
      FOR ALL TO authenticated
      USING (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''))
      WITH CHECK (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));$$;
  END IF;

  -- stops
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='stops' AND policyname='stops_rw'
  ) THEN
    EXECUTE $$CREATE POLICY stops_rw ON public.stops
      FOR ALL TO authenticated
      USING (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''))
      WITH CHECK (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));$$;
  END IF;

  -- assignments
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='assignments' AND policyname='assignments_rw'
  ) THEN
    EXECUTE $$CREATE POLICY assignments_rw ON public.assignments
      FOR ALL TO authenticated
      USING (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''))
      WITH CHECK (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));$$;
  END IF;

  -- load_exceptions
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='load_exceptions' AND policyname='ex_rw'
  ) THEN
    EXECUTE $$CREATE POLICY ex_rw ON public.load_exceptions
      FOR ALL TO authenticated
      USING (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''))
      WITH CHECK (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));$$;
  END IF;

  -- invoices
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='invoices' AND policyname='inv_rw'
  ) THEN
    EXECUTE $$CREATE POLICY inv_rw ON public.invoices
      FOR ALL TO authenticated
      USING (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''))
      WITH CHECK (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));$$;
  END IF;

  -- payments
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='payments' AND policyname='pay_rw'
  ) THEN
    EXECUTE $$CREATE POLICY pay_rw ON public.payments
      FOR ALL TO authenticated
      USING (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''))
      WITH CHECK (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));$$;
  END IF;

  -- ocr_jobs
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='ocr_jobs' AND policyname='ocr_rw'
  ) THEN
    EXECUTE $$CREATE POLICY ocr_rw ON public.ocr_jobs
      FOR ALL TO authenticated
      USING (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''))
      WITH CHECK (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));$$;
  END IF;

  -- positions
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='positions' AND policyname='pos_rw'
  ) THEN
    EXECUTE $$CREATE POLICY pos_rw ON public.positions
      FOR ALL TO authenticated
      USING (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''))
      WITH CHECK (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));$$;
  END IF;

  -- metrics_events (read for org; insert for service_role) — keep existing policies
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='metrics_events' AND policyname='metrics_read'
  ) THEN
    EXECUTE $$CREATE POLICY metrics_read ON public.metrics_events
      FOR SELECT TO authenticated
      USING (org_id IS NULL OR org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));$$;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='metrics_events' AND policyname='metrics_insert_service'
  ) THEN
    EXECUTE $$CREATE POLICY metrics_insert_service ON public.metrics_events
      FOR INSERT TO service_role WITH CHECK (true);$$;
  END IF;
END $$;

-- ========== 2) Hot-path indexes (idempotent) ==========
CREATE INDEX IF NOT EXISTS idx_loads_org_status ON public.loads (org_id, status);
CREATE INDEX IF NOT EXISTS idx_loads_sla_pickup ON public.loads (sla_pickup_by);
CREATE INDEX IF NOT EXISTS idx_loads_sla_delivery ON public.loads (sla_delivery_by);
CREATE INDEX IF NOT EXISTS idx_invoices_org_status_due ON public.invoices (org_id, status, due_at);
CREATE INDEX IF NOT EXISTS idx_positions_org_ts ON public.positions (org_id, ts DESC);

-- ========== 3) Metrics trigger for load status changes ==========
-- Insert an additional metrics row with event_code='status_change' while avoiding duplicates
CREATE OR REPLACE FUNCTION public.trg_load_status_metrics()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND NEW.status IS DISTINCT FROM OLD.status THEN
    -- Skip if a very recent status change event was already recorded for this load (avoid double with existing trigger)
    IF EXISTS (
      SELECT 1 FROM public.metrics_events me
      WHERE me.entity_kind = 'load'
        AND me.entity_id = NEW.id
        AND me.event_code IN ('status_change','load.status.change')
        AND me.ts > now() - interval '1 second'
    ) THEN
      RETURN NEW;
    END IF;

    -- Insert using the broader metrics_events shape used in this repo (jsonb states + tags)
    BEGIN
      INSERT INTO public.metrics_events(org_id, entity_kind, entity_id, event_code, prev_state, new_state, ts, tags)
      VALUES (
        NEW.org_id,
        'load', NEW.id, 'status_change',
        jsonb_build_object('status', OLD.status::text),
        jsonb_build_object('status', NEW.status::text),
        now(),
        jsonb_build_object('ref_no', coalesce(NEW.ref_no,''))
      );
    EXCEPTION WHEN undefined_column THEN
      -- Fallback: minimal insert without tags column
      INSERT INTO public.metrics_events(org_id, entity_kind, entity_id, event_code, prev_state, new_state, ts)
      VALUES (
        NEW.org_id,
        'load', NEW.id, 'status_change',
        jsonb_build_object('status', OLD.status::text),
        jsonb_build_object('status', NEW.status::text),
        now()
      );
    END;
  END IF;
  RETURN NEW;
END$$;

-- Attach AFTER UPDATE trigger (coexist with any existing metrics trigger)
DROP TRIGGER IF EXISTS trg_loads_metrics ON public.loads;
CREATE TRIGGER trg_loads_metrics
AFTER UPDATE ON public.loads
FOR EACH ROW EXECUTE FUNCTION public.trg_load_status_metrics();

-- ========== 4) Optional: SSO failure rate (24h) view (harmless if already present) ==========
CREATE OR REPLACE VIEW public.v_sso_failure_rate_24h AS
SELECT org_id,
       SUM((props->>'attempts_24h')::int) AS attempts_24h,
       SUM((props->>'failures_24h')::int) AS failures_24h,
       CASE WHEN SUM((props->>'attempts_24h')::int) > 0 THEN
         SUM((props->>'failures_24h')::int)::numeric / SUM((props->>'attempts_24h')::int)
       ELSE NULL END AS failure_rate_24h
FROM public.metrics_events
WHERE event_code IN ('sso_health_snapshot')
  AND ts > now() - interval '24 hours'
GROUP BY org_id;
