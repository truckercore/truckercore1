-- 20250929_export_hardening.sql
-- Export hardening: idempotent job schema, DLQ, retention, fingerprint helpers, view, triggers, claim RPC

-- 1) export_jobs table (extend if exists)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='export_jobs'
  ) THEN
    CREATE TABLE public.export_jobs (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      request_fingerprint text NOT NULL,
      org_id uuid,
      user_id uuid,
      route text NOT NULL,
      params jsonb NOT NULL DEFAULT '{}'::jsonb,
      status text NOT NULL DEFAULT 'queued', -- queued|running|succeeded|failed|partial
      attempts int NOT NULL DEFAULT 0,
      max_attempts int NOT NULL DEFAULT 5,
      next_run_at timestamptz DEFAULT now(),
      started_at timestamptz,
      finished_at timestamptz,
      artifact_url text,
      row_count bigint,
      partial boolean DEFAULT false,
      checksum_sha256 text,
      error_reason text,
      error_stack text,
      created_at timestamptz DEFAULT now(),
      updated_at timestamptz DEFAULT now()
    );
  END IF;

  -- Add/ensure columns (idempotent)
  PERFORM 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='export_jobs' AND column_name='request_fingerprint';
  IF NOT FOUND THEN ALTER TABLE public.export_jobs ADD COLUMN request_fingerprint text NOT NULL DEFAULT '';
    -- backfill default empty then drop default
    ALTER TABLE public.export_jobs ALTER COLUMN request_fingerprint DROP DEFAULT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='export_jobs' AND column_name='params') THEN
    ALTER TABLE public.export_jobs ADD COLUMN params jsonb NOT NULL DEFAULT '{}'::jsonb;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='export_jobs' AND column_name='max_attempts') THEN
    ALTER TABLE public.export_jobs ADD COLUMN max_attempts int NOT NULL DEFAULT 5;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='export_jobs' AND column_name='next_run_at') THEN
    ALTER TABLE public.export_jobs ADD COLUMN next_run_at timestamptz DEFAULT now();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='export_jobs' AND column_name='started_at') THEN
    ALTER TABLE public.export_jobs ADD COLUMN started_at timestamptz;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='export_jobs' AND column_name='finished_at') THEN
    ALTER TABLE public.export_jobs ADD COLUMN finished_at timestamptz;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='export_jobs' AND column_name='artifact_url') THEN
    ALTER TABLE public.export_jobs ADD COLUMN artifact_url text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='export_jobs' AND column_name='row_count') THEN
    ALTER TABLE public.export_jobs ADD COLUMN row_count bigint;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='export_jobs' AND column_name='partial') THEN
    ALTER TABLE public.export_jobs ADD COLUMN partial boolean DEFAULT false;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='export_jobs' AND column_name='checksum_sha256') THEN
    ALTER TABLE public.export_jobs ADD COLUMN checksum_sha256 text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='export_jobs' AND column_name='error_reason') THEN
    ALTER TABLE public.export_jobs ADD COLUMN error_reason text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='export_jobs' AND column_name='error_stack') THEN
    ALTER TABLE public.export_jobs ADD COLUMN error_stack text;
  END IF;
END$$;

-- Unique index on request_fingerprint
CREATE UNIQUE INDEX IF NOT EXISTS export_jobs_request_fingerprint_uidx ON public.export_jobs (request_fingerprint);

-- 2) DLQ table
CREATE TABLE IF NOT EXISTS public.export_jobs_dlq (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id uuid,
  org_id uuid,
  user_id uuid,
  route text,
  params jsonb,
  attempts int,
  reason text,
  stack text,
  payload jsonb,
  created_at timestamptz DEFAULT now(),
  resolved_at timestamptz
);

-- 3) Lightweight audit for PII exports (create if not exists only)
CREATE TABLE IF NOT EXISTS public.export_audit (
  id bigserial PRIMARY KEY,
  export_id uuid,
  org_id uuid,
  user_id uuid,
  route text,
  include_sensitive boolean DEFAULT false,
  selected_columns text[],
  created_at timestamptz DEFAULT now()
);

-- 4) Retention sweep function
CREATE OR REPLACE FUNCTION public.retention_sweep_exports()
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM public.export_jobs WHERE created_at < now() - INTERVAL '180 days';
  DELETE FROM public.export_jobs_dlq WHERE created_at < now() - INTERVAL '365 days' AND resolved_at IS NOT NULL;
  DELETE FROM public.export_audit WHERE created_at < now() - INTERVAL '365 days';
END $$;

-- 5) Request fingerprint helper
CREATE OR REPLACE FUNCTION public.request_fingerprint_sql(p_org uuid, p_user uuid, p_route text, p_params jsonb)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT encode(digest(coalesce(p_org::text,'') || ':' || coalesce(p_user::text,'') || ':' || coalesce(p_route,'') || ':' || coalesce(p_params::text,'{}'), 'sha256'), 'hex');
$$;

-- 6) Safety export view (server-only consumption)
CREATE OR REPLACE VIEW public.export_safety_view AS
SELECT
  a.id,
  a.org_id,
  a.user_id AS driver_id,
  a.source,
  a.event_type::text AS event_type,
  a.title,
  a.message,
  a.severity::text AS severity,
  st_x(a.geom) AS lon,
  st_y(a.geom) AS lat,
  a.context,
  a.created_at
FROM public.alert_events a;

GRANT SELECT ON public.export_safety_view TO service_role;

-- 7) touch updated_at trigger
CREATE OR REPLACE FUNCTION public.tg_touch_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_export_jobs_touch ON public.export_jobs;
CREATE TRIGGER trg_export_jobs_touch BEFORE UPDATE ON public.export_jobs
FOR EACH ROW EXECUTE PROCEDURE public.tg_touch_updated_at();

-- 8) Job claimer RPC (skip locked)
CREATE OR REPLACE FUNCTION public.claim_export_job()
RETURNS public.export_jobs
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  rec export_jobs;
BEGIN
  WITH cte AS (
    SELECT id FROM public.export_jobs
    WHERE status IN ('queued','failed') AND COALESCE(next_run_at, now()) <= now()
    ORDER BY created_at
    FOR UPDATE SKIP LOCKED
    LIMIT 1
  )
  UPDATE public.export_jobs j
  SET status='running', started_at=now(), attempts=j.attempts + 1
  FROM cte
  WHERE j.id = cte.id
  RETURNING j.* INTO rec;

  RETURN rec;
END $$;

REVOKE ALL ON FUNCTION public.claim_export_job() FROM public;
GRANT EXECUTE ON FUNCTION public.claim_export_job() TO service_role;
