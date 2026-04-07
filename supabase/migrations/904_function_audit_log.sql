-- 904_function_audit_log.sql
-- Ensure function_audit_log table exists and is protected by RLS with read access for admins/dispatchers

CREATE TABLE IF NOT EXISTS public.function_audit_log (
  id bigserial PRIMARY KEY,
  fn text NOT NULL,
  actor uuid,
  payload_sha256 text,
  success boolean,
  error text,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.function_audit_log ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='public' AND tablename='function_audit_log' AND policyname='fn_log_read_admins'
  ) THEN
    CREATE POLICY fn_log_read_admins ON public.function_audit_log
    FOR SELECT USING (
      EXISTS(
        SELECT 1 FROM public.profiles p
        WHERE p.user_id = auth.uid()
          AND p.role IN ('admin','dispatcher')
      )
    );
  END IF;
END $$;
