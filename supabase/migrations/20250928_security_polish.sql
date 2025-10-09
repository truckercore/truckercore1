-- 20250928_security_polish.sql
-- Service-only RPC grant tightening and ETL/job indexes & triggers

-- Service-only RPC (integration_status_for_org) if it exists
DO $$
BEGIN
  PERFORM 1 FROM pg_proc WHERE proname = 'integration_status_for_org';
  IF FOUND THEN
    REVOKE EXECUTE ON FUNCTION integration_status_for_org(uuid) FROM PUBLIC;
    GRANT EXECUTE ON FUNCTION integration_status_for_org(uuid) TO service_role;
  END IF;
END $$;

-- Partial index to speed up ETL queue polling
CREATE INDEX IF NOT EXISTS idx_etl_jobs_queued ON public.etl_jobs(status) WHERE status = 'queued';

-- updated_at trigger function
CREATE OR REPLACE FUNCTION public.set_updated_at() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END$$;

-- Attach trigger to integration_connections if table exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema='public' AND table_name='integration_connections'
  ) THEN
    DROP TRIGGER IF EXISTS t_upd_conn ON public.integration_connections;
    CREATE TRIGGER t_upd_conn BEFORE UPDATE ON public.integration_connections
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
  END IF;
END $$;