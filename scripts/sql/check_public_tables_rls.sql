-- check_public_tables_rls.sql
-- Purpose: Ensure all base tables in the public schema have Row Level Security (RLS) enabled.
-- Fails with an error if any table in public does not have RLS enabled.
--
-- CI usage:
--   psql -v ON_ERROR_STOP=1 -f scripts/sql/check_public_tables_rls.sql
--
-- Notes:
-- - We check regular and partitioned tables (relkind in ('r','p')).
-- - Views, materialized views, foreign tables, and sequences are excluded.
-- - If you truly need to exempt a table, add it to the WHITELIST CTE below with a comment and justification.

\echo Checking RLS on public tables...

DO $$
DECLARE
  violations int;
  viol_list text;
BEGIN
  WITH whitelist AS (
    -- Add any intentionally RLS-disabled public tables here, one per row, with justification.
    -- Example:
    -- SELECT 'legacy_unsecured_table'::text AS relname, 'temporary exception until <date>'::text AS reason
    SELECT NULL::text AS relname, NULL::text AS reason
    WHERE false
  ),
  public_tables AS (
    SELECT c.oid, n.nspname, c.relname, c.relrowsecurity
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relkind IN ('r','p') -- base table or partitioned table
  ),
  bad AS (
    SELECT pt.nspname, pt.relname
    FROM public_tables pt
    LEFT JOIN whitelist w ON w.relname = pt.relname
    WHERE (w.relname IS NULL) -- not whitelisted
      AND (COALESCE(pt.relrowsecurity, false) = false)
  )
  SELECT COUNT(*) AS cnt, COALESCE(string_agg(quote_ident(relname), ', '), '') AS list
  INTO violations, viol_list
  FROM bad;

  IF violations > 0 THEN
    RAISE EXCEPTION 'RLS is NOT enabled for % public table(s): %', violations, viol_list
      USING HINT = 'Enable RLS using: ALTER TABLE public.<table> ENABLE ROW LEVEL SECURITY; and add policies as needed.';
  ELSE
    RAISE NOTICE 'All public tables have RLS enabled.';
  END IF;
END$$;
