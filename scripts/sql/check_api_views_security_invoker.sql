-- check_api_views_security_invoker.sql
-- Purpose: Ensure all views in the api schema are defined with SECURITY INVOKER semantics.
-- Postgres 15+ supports view option: WITH (security_invoker = true)
-- Fails with an error if any api view is not marked as security_invoker=true.
--
-- CI usage:
--   psql -v ON_ERROR_STOP=1 -f scripts/sql/check_api_views_security_invoker.sql

\echo Checking that api views use SECURITY INVOKER...

DO $$
DECLARE
  violations int;
  viol_list text;
BEGIN
  WITH api_views AS (
    SELECT n.nspname, c.relname, c.reloptions
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'api'
      AND c.relkind = 'v' -- view
  ),
  bad AS (
    SELECT av.nspname, av.relname
    FROM api_views av
    WHERE NOT EXISTS (
      SELECT 1
      FROM unnest(COALESCE(av.reloptions, ARRAY[]::text[])) opt
      WHERE opt = 'security_invoker=true'
    )
  )
  SELECT COUNT(*) AS cnt, COALESCE(string_agg(quote_ident(relname), ', '), '') AS list
  INTO violations, viol_list
  FROM bad;

  IF violations > 0 THEN
    RAISE EXCEPTION 'Found % api view(s) without SECURITY INVOKER: %', violations, viol_list
      USING HINT = 'Recreate the view(s) with: CREATE OR REPLACE VIEW api.<view> WITH (security_invoker=true) AS SELECT ...';
  ELSE
    RAISE NOTICE 'All api views have SECURITY INVOKER enabled.';
  END IF;
END$$;