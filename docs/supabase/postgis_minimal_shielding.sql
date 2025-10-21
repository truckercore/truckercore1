-- Minimal shielding if public schema is ever temporarily exposed
-- Goal: Ensure PostgREST exposed schemas exclude public. If you must expose public
-- briefly, revoke privileges on public.spatial_ref_sys from anon/authenticated to
-- prevent data leakage. This script is safe to run multiple times.
-- Note: Full effectiveness depends on ownership; managed platforms may restrict this.

-- 0) Reminder output
\echo 'Reminder: In API settings, set exposed schemas to: api (and maybe auth, storage). Exclude public.'

-- 1) Enable RLS on spatial_ref_sys (also helps some linters)
DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema='public' AND table_name='spatial_ref_sys'
  ) THEN
    EXECUTE 'ALTER TABLE public.spatial_ref_sys ENABLE ROW LEVEL SECURITY';
    EXECUTE 'DROP POLICY IF EXISTS spatial_ref_sys_read ON public.spatial_ref_sys';
    EXECUTE 'CREATE POLICY spatial_ref_sys_read ON public.spatial_ref_sys FOR SELECT USING (true)';
  END IF;
END $$;

-- 2) Revoke privileges from anon/authenticated on spatial_ref_sys if possible
DO $$
DECLARE
  sql text;
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema='public' AND table_name='spatial_ref_sys'
  ) THEN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname='anon') THEN
      BEGIN
        sql := 'REVOKE ALL ON TABLE public.spatial_ref_sys FROM anon';
        EXECUTE sql;
      EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'Insufficient privilege to revoke from anon on public.spatial_ref_sys. Skipping.';
      WHEN object_not_in_prerequisite_state THEN
        RAISE NOTICE 'Cannot revoke from anon due to ownership/state. Skipping.';
      END;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN
      BEGIN
        sql := 'REVOKE ALL ON TABLE public.spatial_ref_sys FROM authenticated';
        EXECUTE sql;
      EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'Insufficient privilege to revoke from authenticated on public.spatial_ref_sys. Skipping.';
      WHEN object_not_in_prerequisite_state THEN
        RAISE NOTICE 'Cannot revoke from authenticated due to ownership/state. Skipping.';
      END;
    END IF;
  END IF;
END $$;

-- 3) Optional: lock down schema-level CREATE on public from untrusted roles
DO $$ BEGIN
  -- Never grant CREATE on public to app roles
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname='anon') THEN
    EXECUTE 'REVOKE CREATE ON SCHEMA public FROM anon';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN
    EXECUTE 'REVOKE CREATE ON SCHEMA public FROM authenticated';
  END IF;
  -- PUBLIC (everyone) should not have CREATE on public
  EXECUTE 'REVOKE CREATE ON SCHEMA public FROM PUBLIC';
END $$;
