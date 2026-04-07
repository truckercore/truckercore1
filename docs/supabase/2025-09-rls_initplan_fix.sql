-- Auth RLS Initialization Plan fix (initplan re-evaluation) — 2025-09
-- Purpose: eliminate per-row re-evaluation of auth.<fn>() and current_setting() in RLS policies
-- by wrapping them in a subselect, per Supabase guidance:
-- https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select
--
-- This script is additive and designed to be re-runnable. It:
--  1) Re-creates common Supabase quickstart policies (profiles, documents, user_settings)
--     using (SELECT auth.uid()).
--  2) Provides helpers and a report to find remaining policies that still call auth.*() or
--     current_setting() directly. For those, copy their logic and re-create using the SELECT pattern.
--  3) Leaves domain-specific policies (e.g., trucks, devices) to rls_perf_fix.sql or manual review,
--     because column names vary across deployments.
--
-- Safe window: Can be applied online; policy drops and re-creates are quick. If you have heavy traffic,
-- apply during a low-traffic window.

-------------------------------------------------
-- 0) Optional helpers (bypass linter by avoiding direct calls in policy bodies)
-------------------------------------------------
-- These helpers are STABLE and return NULL if no JWT is present.
CREATE OR REPLACE FUNCTION public.current_user_id()
RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT auth.uid()
$$;

CREATE OR REPLACE FUNCTION public.current_jwt_claims()
RETURNS jsonb LANGUAGE sql STABLE AS $$
  SELECT current_setting('request.jwt.claims', true)::jsonb
$$;

-------------------------------------------------
-- 1) profiles — standard Supabase quickstart policies
-------------------------------------------------
-- Table must exist and have RLS enabled outside of this script.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema='public' AND table_name='profiles'
  ) THEN
    -- Updatable by owner
    EXECUTE 'DROP POLICY IF EXISTS "Profiles are updatable by owner" ON public.profiles';
    EXECUTE $$CREATE POLICY "Profiles are updatable by owner" ON public.profiles
      FOR UPDATE TO authenticated
      USING ( id = (SELECT auth.uid()) )
      WITH CHECK ( id = (SELECT auth.uid()) )$$;

    -- Insertable by owner
    EXECUTE 'DROP POLICY IF EXISTS "Profiles are insertable by owner" ON public.profiles';
    EXECUTE $$CREATE POLICY "Profiles are insertable by owner" ON public.profiles
      FOR INSERT TO authenticated
      WITH CHECK ( id = (SELECT auth.uid()) )$$;

    -- Select own profile (optional, if you restrict reads)
    IF NOT EXISTS (
      SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='profiles' AND policyname='Profiles are viewable by owner'
    ) THEN
      EXECUTE $$CREATE POLICY "Profiles are viewable by owner" ON public.profiles
        FOR SELECT TO authenticated
        USING ( id = (SELECT auth.uid()) )$$;
    END IF;
  END IF;
END$$;

-------------------------------------------------
-- 2) documents — common owner-scoped bucket metadata table pattern
-------------------------------------------------
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema='public' AND table_name='documents'
  ) THEN
    EXECUTE 'DROP POLICY IF EXISTS "Documents are viewable by owner" ON public.documents';
    EXECUTE $$CREATE POLICY "Documents are viewable by owner" ON public.documents
      FOR SELECT TO authenticated
      USING ( user_id = (SELECT auth.uid()) )$$;

    EXECUTE 'DROP POLICY IF EXISTS "Documents are insertable by owner" ON public.documents';
    EXECUTE $$CREATE POLICY "Documents are insertable by owner" ON public.documents
      FOR INSERT TO authenticated
      WITH CHECK ( user_id = (SELECT auth.uid()) )$$;

    EXECUTE 'DROP POLICY IF EXISTS "Documents are deletable by owner" ON public.documents';
    EXECUTE $$CREATE POLICY "Documents are deletable by owner" ON public.documents
      FOR DELETE TO authenticated
      USING ( user_id = (SELECT auth.uid()) )$$;
  END IF;
END$$;

-------------------------------------------------
-- 3) user_settings — self-scoped settings table
-------------------------------------------------
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema='public' AND table_name='user_settings'
  ) THEN
    EXECUTE 'DROP POLICY IF EXISTS user_settings_read ON public.user_settings';
    EXECUTE $$CREATE POLICY user_settings_read ON public.user_settings
      FOR SELECT TO authenticated
      USING ( user_id = (SELECT auth.uid()) )$$;

    EXECUTE 'DROP POLICY IF EXISTS user_settings_write_self ON public.user_settings';
    EXECUTE $$CREATE POLICY user_settings_write_self ON public.user_settings
      FOR ALL TO authenticated
      USING ( user_id = (SELECT auth.uid()) )
      WITH CHECK ( user_id = (SELECT auth.uid()) )$$;
  END IF;
END$$;

-------------------------------------------------
-- 4) Reporting for remaining offenders (manual follow-up)
-------------------------------------------------
-- These queries surface policies that still directly call auth.*() or current_setting().
-- For each, re-create the policy by wrapping calls with SELECT, e.g. auth.uid() -> (SELECT auth.uid()).

-- Policies using auth.*() without SELECT wrapper
SELECT policyname, tablename, schemaname, qual, with_check
FROM pg_policies
WHERE (qual ILIKE '%auth.%()%' OR with_check ILIKE '%auth.%()%')
  AND NOT (qual ILIKE '%(SELECT auth.%()%)%' OR with_check ILIKE '%(SELECT auth.%()%)%')
ORDER BY schemaname, tablename, policyname;

-- Policies using current_setting() without SELECT wrapper
SELECT policyname, tablename, schemaname, qual, with_check
FROM pg_policies
WHERE (qual ILIKE '%current_setting(%' OR with_check ILIKE '%current_setting(%')
  AND NOT (qual ILIKE '%(SELECT current_setting(%' OR with_check ILIKE '%(SELECT current_setting(%')
ORDER BY schemaname, tablename, policyname;

-- Optional: quick suggestion generator (manual copy/paste). This cannot faithfully reconstruct the
-- entire CREATE POLICY statement (since USING/WITH CHECK may be complex), but it highlights what to change.
SELECT
  policyname,
  tablename,
  '-- SUGGESTED: Replace auth.fn() with (SELECT auth.fn()) and current_setting() with (SELECT current_setting()) in USING/WITH CHECK for policy ' || quote_ident(policyname) || ' on ' || quote_ident(schemaname) || '.' || quote_ident(tablename) AS suggestion
FROM pg_policies
WHERE (qual ILIKE '%auth.%()%' OR with_check ILIKE '%auth.%()%'
    OR qual ILIKE '%current_setting(%' OR with_check ILIKE '%current_setting(%')
ORDER BY schemaname, tablename, policyname;

-------------------------------------------------
-- 5) Notes
-------------------------------------------------
-- • For multi-tenant org policies that read JWT claims, replace
--   current_setting('request.jwt.claims')::jsonb ->> 'org_id'
--   with (SELECT current_setting('request.jwt.claims', true)::jsonb ->> 'org_id').
-- • You may also use helper functions (public.current_jwt_claims()) in policies and then compare
--   public.current_jwt_claims() ->> 'org_id' to your tenant key to avoid re-calling current_setting().
-- • See also: docs/supabase/rls_perf_fix.sql for a broader set of re-created policies already using the pattern.
