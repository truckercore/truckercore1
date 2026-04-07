-- Export jobs and export_audit columns extension (idempotent)

-- Extend export_audit with columns used by API if missing
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='export_audit' AND column_name='bytes'
  ) THEN
    ALTER TABLE public.export_audit ADD COLUMN bytes int;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='export_audit' AND column_name='checksum'
  ) THEN
    ALTER TABLE public.export_audit ADD COLUMN checksum text;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='export_audit' AND column_name='include_sensitive'
  ) THEN
    ALTER TABLE public.export_audit ADD COLUMN include_sensitive boolean NOT NULL DEFAULT false;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='export_audit' AND column_name='columns'
  ) THEN
    ALTER TABLE public.export_audit ADD COLUMN columns text[];
  END IF;
END $$;

-- Create export_jobs table for async exports
CREATE TABLE IF NOT EXISTS public.export_jobs (
  id uuid PRIMARY KEY,
  route text NOT NULL,
  org_id uuid NULL,
  user_id uuid NULL,
  status text NOT NULL CHECK (status IN ('queued','running','done','failed')),
  options jsonb NOT NULL DEFAULT '{}'::jsonb,
  signed_url text NULL,
  error text NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NULL
);

-- Helpful index
CREATE INDEX IF NOT EXISTS idx_export_jobs_status ON public.export_jobs (status, created_at DESC);

-- RLS enable + simple org-scoped read
ALTER TABLE public.export_jobs ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='export_jobs' AND policyname='export_jobs_read_org'
  ) THEN
    CREATE POLICY export_jobs_read_org ON public.export_jobs
      FOR SELECT TO authenticated
      USING (org_id::text = COALESCE(current_setting('request.jwt.claims', true)::jsonb->>'app_org_id',
                                      current_setting('request.jwt.claims', true)::jsonb->>'org_id'));
  END IF;
END $$;

-- Grants for service role to insert/update jobs
GRANT INSERT, UPDATE ON public.export_jobs TO service_role;

-- Ensure private storage bucket 'exports' exists (for async CSV .csv.gz files)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM storage.buckets WHERE id = 'exports') THEN
    INSERT INTO storage.buckets (id, name, public) VALUES ('exports','exports', false);
  END IF;
END $$;
