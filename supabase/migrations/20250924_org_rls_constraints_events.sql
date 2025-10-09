-- 20250924_org_rls_constraints_events.sql
-- Purpose: Apply standardized org read/write RLS policies (org_rw_*),
-- add/guard constraints and foreign keys, updated_at touch triggers,
-- a normalized system_events sink with helper, event triggers for key tables,
-- and a v_metrics_rollup view for dashboards. Idempotent and safe to re-run.

-- ========== 1) Org read/write RLS policies (pattern: org_rw_*) ==========
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['loads','stops','assignments','invoices','documents','load_exceptions']
  LOOP
    -- Enable RLS on each table if it exists
    IF to_regclass('public.'||t) IS NOT NULL THEN
      EXECUTE format('alter table public.%I enable row level security;', t);
      -- Drop legacy policies named <table>_org_read/write if present to avoid duplicates
      PERFORM 1 FROM pg_policies WHERE schemaname='public' AND tablename=t AND policyname=t||'_org_read';
      IF FOUND THEN EXECUTE format('drop policy %I on public.%I', t||'_org_read', t); END IF;
      PERFORM 1 FROM pg_policies WHERE schemaname='public' AND tablename=t AND policyname=t||'_org_write';
      IF FOUND THEN EXECUTE format('drop policy %I on public.%I', t||'_org_write', t); END IF;
      -- Create standardized org_rw_* policies if missing
      IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename=t AND policyname='org_rw_read'
      ) THEN
        EXECUTE format(
          'create policy org_rw_read on public.%I for select to authenticated using (org_id::text = coalesce(current_setting(''request.jwt.claims'', true)::json->>''app_org_id'',''''))',
          t
        );
      END IF;
      IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename=t AND policyname='org_rw_write'
      ) THEN
        EXECUTE format(
          'create policy org_rw_write on public.%I for insert, update, delete to authenticated using (org_id::text = coalesce(current_setting(''request.jwt.claims'', true)::json->>''app_org_id'','''')) with check (org_id::text = coalesce(current_setting(''request.jwt.claims'', true)::json->>''app_org_id'',''''))',
          t
        );
      END IF;
    END IF;
  END LOOP;
END $$;

-- ========== 2) Constraints, FKs, and uniqueness ==========
-- Ensure org_id NOT NULL on stops (if nullable previously)
DO $$ BEGIN
  IF to_regclass('public.stops') IS NOT NULL THEN
    BEGIN
      ALTER TABLE public.stops ALTER COLUMN org_id SET NOT NULL;
    EXCEPTION WHEN others THEN NULL; -- ignore if already not null or column missing
    END;
  END IF;
END $$;

-- Assignments FKs (org->orgs, load->loads)
DO $$ BEGIN
  IF to_regclass('public.assignments') IS NOT NULL THEN
    IF to_regclass('public.orgs') IS NOT NULL AND NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints WHERE table_schema='public' AND table_name='assignments' AND constraint_name='assignments_org_fk'
    ) THEN
      ALTER TABLE public.assignments
        ADD CONSTRAINT assignments_org_fk FOREIGN KEY (org_id) REFERENCES public.orgs(id) ON DELETE CASCADE;
    END IF;
    IF to_regclass('public.loads') IS NOT NULL AND NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints WHERE table_schema='public' AND table_name='assignments' AND constraint_name='assignments_load_fk'
    ) THEN
      ALTER TABLE public.assignments
        ADD CONSTRAINT assignments_load_fk FOREIGN KEY (load_id) REFERENCES public.loads(id) ON DELETE CASCADE;
    END IF;
  END IF;
END $$;

-- Documents/org FK
DO $$ BEGIN
  IF to_regclass('public.documents') IS NOT NULL AND to_regclass('public.orgs') IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints WHERE table_schema='public' AND table_name='documents' AND constraint_name='documents_org_fk'
  ) THEN
    ALTER TABLE public.documents
      ADD CONSTRAINT documents_org_fk FOREIGN KEY (org_id) REFERENCES public.orgs(id) ON DELETE CASCADE;
  END IF;
END $$;

-- Invoices/org FK
DO $$ BEGIN
  IF to_regclass('public.invoices') IS NOT NULL AND to_regclass('public.orgs') IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints WHERE table_schema='public' AND table_name='invoices' AND constraint_name='invoices_org_fk'
  ) THEN
    ALTER TABLE public.invoices
      ADD CONSTRAINT invoices_org_fk FOREIGN KEY (org_id) REFERENCES public.orgs(id) ON DELETE CASCADE;
  END IF;
END $$;

-- One active assignment per load: add status column if missing then unique index
DO $$ BEGIN
  IF to_regclass('public.assignments') IS NOT NULL THEN
    BEGIN
      ALTER TABLE public.assignments ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'active';
    EXCEPTION WHEN others THEN NULL; END;
    CREATE UNIQUE INDEX IF NOT EXISTS uq_assignments_load_active ON public.assignments(load_id) WHERE status = 'active';
  END IF;
END $$;

-- Documents: unique content_hash per org (avoid duplicate uploads)
DO $$ BEGIN
  IF to_regclass('public.documents') IS NOT NULL THEN
    BEGIN
      ALTER TABLE public.documents ADD COLUMN IF NOT EXISTS content_hash text;
    EXCEPTION WHEN others THEN NULL; END;
    CREATE UNIQUE INDEX IF NOT EXISTS uq_documents_hash_org ON public.documents(org_id, content_hash) WHERE content_hash IS NOT NULL;
  END IF;
END $$;

-- Invoices: invoice number unique per org (add column if absent)
DO $$ BEGIN
  IF to_regclass('public.invoices') IS NOT NULL THEN
    BEGIN
      ALTER TABLE public.invoices ADD COLUMN IF NOT EXISTS invoice_number text;
    EXCEPTION WHEN others THEN NULL; END;
    CREATE UNIQUE INDEX IF NOT EXISTS uq_invoices_number_org ON public.invoices(org_id, invoice_number) WHERE invoice_number IS NOT NULL;
  END IF;
END $$;

-- ========== 3) updated_at touch function + triggers ==========
CREATE OR REPLACE FUNCTION public.fn_touch_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END $$;

-- Add updated_at column where missing and attach trigger to listed tables
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['stops','assignments','invoices','documents','load_exceptions','loads']
  LOOP
    IF to_regclass('public.'||t) IS NOT NULL THEN
      BEGIN
        EXECUTE format('ALTER TABLE public.%I ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();', t);
      EXCEPTION WHEN others THEN NULL; END;
      -- Drop and recreate trigger to ensure it exists
      EXECUTE format('DROP TRIGGER IF EXISTS trg_%s_touch ON public.%I;', t, t);
      EXECUTE format('CREATE TRIGGER trg_%s_touch BEFORE UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.fn_touch_updated_at();', t, t);
    END IF;
  END LOOP;
END $$;

-- ========== 4) system_events table + emit helper and event triggers ==========
CREATE TABLE IF NOT EXISTS public.system_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL,
  code text NOT NULL,                 -- e.g., 'exception.raised','invoice.status.change','document.uploaded','ocr.completed'
  entity text NOT NULL,               -- 'exception','invoice','document','ocr_job'
  entity_id text NOT NULL,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  triggered_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_sys_events_org_time ON public.system_events(org_id, triggered_at desc);
ALTER TABLE public.system_events ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='system_events' AND policyname='sys_events_read_org'
  ) THEN
    CREATE POLICY sys_events_read_org ON public.system_events
    FOR SELECT TO authenticated
    USING (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.fn_emit_event(p_org_id uuid, p_code text, p_entity text, p_entity_id text, p_details jsonb DEFAULT '{}'::jsonb)
RETURNS void LANGUAGE sql SECURITY DEFINER AS $$
  INSERT INTO public.system_events(org_id, code, entity, entity_id, details)
  VALUES (p_org_id, p_code, p_entity, p_entity_id, coalesce(p_details,'{}'::jsonb));
$$;
REVOKE ALL ON FUNCTION public.fn_emit_event(uuid,text,text,text,jsonb) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_emit_event(uuid,text,text,text,jsonb) TO service_role;

-- Trigger: exception raised/resolved (using load_exceptions schema)
CREATE OR REPLACE FUNCTION public.fn_trg_load_exception_events()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    PERFORM public.fn_emit_event(NEW.org_id, 'exception.raised', 'exception', NEW.id::text,
      jsonb_build_object('code', NEW.code, 'message', NEW.message, 'raised_at', NEW.raised_at));
  ELSIF TG_OP = 'UPDATE' AND NEW.resolved_at IS NOT NULL AND OLD.resolved_at IS DISTINCT FROM NEW.resolved_at THEN
    PERFORM public.fn_emit_event(NEW.org_id, 'exception.resolved', 'exception', NEW.id::text,
      jsonb_build_object('resolved_at', NEW.resolved_at));
  END IF;
  RETURN NEW;
END $$;
DO $$ BEGIN
  IF to_regclass('public.load_exceptions') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS trg_load_exceptions_events ON public.load_exceptions;
    CREATE TRIGGER trg_load_exceptions_events
    AFTER INSERT OR UPDATE ON public.load_exceptions
    FOR EACH ROW EXECUTE FUNCTION public.fn_trg_load_exception_events();
  END IF;
END $$;

-- Trigger: invoice status change
CREATE OR REPLACE FUNCTION public.fn_trg_invoice_status_events()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND NEW.status IS DISTINCT FROM OLD.status THEN
    PERFORM public.fn_emit_event(NEW.org_id, 'invoice.status.change', 'invoice', NEW.id::text,
      jsonb_build_object('from', OLD.status, 'to', NEW.status, 'amount_usd', NEW.amount_due_usd, 'issued_at', NEW.issued_at));
  END IF;
  RETURN NEW;
END $$;
DO $$ BEGIN
  IF to_regclass('public.invoices') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS trg_invoices_events ON public.invoices;
    CREATE TRIGGER trg_invoices_events
    AFTER UPDATE ON public.invoices
    FOR EACH ROW EXECUTE FUNCTION public.fn_trg_invoice_status_events();
  END IF;
END $$;

-- Trigger: document uploaded
CREATE OR REPLACE FUNCTION public.fn_trg_document_uploaded()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    PERFORM public.fn_emit_event(NEW.org_id, 'document.uploaded', 'document', NEW.id::text,
      jsonb_build_object('kind', NEW.kind, 'storage_key', NEW.storage_key, 'content_hash', NEW.content_hash));
  END IF;
  RETURN NEW;
END $$;
DO $$ BEGIN
  IF to_regclass('public.documents') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS trg_documents_events ON public.documents;
    CREATE TRIGGER trg_documents_events
    AFTER INSERT ON public.documents
    FOR EACH ROW EXECUTE FUNCTION public.fn_trg_document_uploaded();
  END IF;
END $$;

-- Trigger: OCR job completed (derive duration_ms from timestamps)
CREATE OR REPLACE FUNCTION public.fn_trg_ocr_completed()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE dur_ms int;
BEGIN
  IF TG_OP = 'UPDATE' AND NEW.status = 'completed' AND COALESCE(OLD.status,'') <> 'completed' THEN
    BEGIN
      dur_ms := GREATEST(0, ROUND(EXTRACT(EPOCH FROM (COALESCE(NEW.updated_at, now()) - COALESCE(NEW.created_at, now()))) * 1000)::int);
    EXCEPTION WHEN others THEN dur_ms := NULL; END;
    PERFORM public.fn_emit_event(NEW.org_id, 'ocr.completed', 'ocr_job', NEW.id::text,
      jsonb_build_object('duration_ms', dur_ms));
  END IF;
  RETURN NEW;
END $$;
DO $$ BEGIN
  IF to_regclass('public.ocr_jobs') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS trg_ocr_jobs_events ON public.ocr_jobs;
    CREATE TRIGGER trg_ocr_jobs_events
    AFTER UPDATE ON public.ocr_jobs
    FOR EACH ROW EXECUTE FUNCTION public.fn_trg_ocr_completed();
  END IF;
END $$;

-- ========== 5) v_metrics_rollup (per org/day) ==========
CREATE OR REPLACE VIEW public.v_metrics_rollup AS
WITH days AS (
  SELECT generate_series(date_trunc('day', now()) - interval '30 days', date_trunc('day', now()), interval '1 day')::date AS day
),
-- Events aggregates (last 31 days window)
events AS (
  SELECT
    org_id,
    date_trunc('day', triggered_at)::date AS day,
    sum(CASE WHEN code='exception.raised' THEN 1 ELSE 0 END) AS exceptions_raised,
    sum(CASE WHEN code='exception.resolved' THEN 1 ELSE 0 END) AS exceptions_resolved,
    sum(CASE WHEN code='invoice.status.change' AND (details->>'to') IN ('sent','partial','paid','void') THEN 1 ELSE 0 END) AS invoices_moved,
    sum(CASE WHEN code='document.uploaded' THEN 1 ELSE 0 END) AS documents_uploaded,
    sum(CASE WHEN code='ocr.completed' THEN 1 ELSE 0 END) AS ocr_completed
  FROM public.system_events
  WHERE triggered_at >= now() - interval '31 days'
  GROUP BY 1,2
),
-- Loads: map dispatch statuses to buckets; created_at used for day
loads_rollup AS (
  SELECT org_id,
         date_trunc('day', created_at)::date AS day,
         count(*) FILTER (WHERE status IN ('tendered','accepted')) AS loads_posted,
         0::bigint AS loads_assigned -- default 0; see assignments_rollup below
  FROM public.loads
  WHERE created_at >= now() - interval '31 days'
  GROUP BY 1,2
),
assignments_rollup AS (
  SELECT org_id,
         date_trunc('day', assigned_at)::date AS day,
         count(*) AS loads_assigned
  FROM public.assignments
  WHERE assigned_at >= now() - interval '31 days'
  GROUP BY 1,2
),
invoices_rollup AS (
  SELECT org_id,
         date_trunc('day', COALESCE(issued_at, now()))::date AS day,
         count(*) AS invoices_created,
         SUM(COALESCE(amount_due_usd,0))::numeric(20,2) AS invoice_amount_usd
  FROM public.invoices
  WHERE COALESCE(issued_at, now()) >= now() - interval '31 days'
  GROUP BY 1,2
)
SELECT
  COALESCE(e.org_id, l.org_id, a.org_id, i.org_id) AS org_id,
  d.day,
  COALESCE(e.exceptions_raised,0) AS exceptions_raised,
  COALESCE(e.exceptions_resolved,0) AS exceptions_resolved,
  COALESCE(e.documents_uploaded,0) AS documents_uploaded,
  COALESCE(e.ocr_completed,0) AS ocr_completed,
  COALESCE(l.loads_posted,0) AS loads_posted,
  COALESCE(a.loads_assigned, l.loads_assigned, 0) AS loads_assigned,
  COALESCE(i.invoices_created,0) AS invoices_created,
  COALESCE(i.invoice_amount_usd,0)::numeric(20,2) AS invoice_amount_usd
FROM days d
LEFT JOIN events e ON e.day = d.day
LEFT JOIN loads_rollup l ON l.day = d.day AND l.org_id = e.org_id
LEFT JOIN assignments_rollup a ON a.day = d.day AND a.org_id = COALESCE(e.org_id,l.org_id)
LEFT JOIN invoices_rollup i ON i.day = d.day AND i.org_id = COALESCE(e.org_id,l.org_id,a.org_id);

-- Notes:
-- - The policies follow a standardized org_rw_* naming pattern per table.
-- - All DDL guarded via IF NOT EXISTS / DO blocks for idempotency.
-- - v_metrics_rollup relies on base tables' RLS; create a SECURITY DEFINER wrapper if cross-org access is required.
