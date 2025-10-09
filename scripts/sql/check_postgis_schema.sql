-- check_postgis_schema.sql
-- Purpose: Report where the PostGIS extension is installed and whether it is in the
--          dedicated 'extensions' schema. This script is informational and does NOT fail CI.
-- Usage:
--   psql -v ON_ERROR_STOP=1 -f scripts/sql/check_postgis_schema.sql

\echo Checking PostGIS installation schema...

DO $$
DECLARE
  ext_schema text;
BEGIN
  SELECT n.nspname INTO ext_schema
  FROM pg_extension e
  JOIN pg_namespace n ON n.oid = e.extnamespace
  WHERE e.extname = 'postgis';

  IF ext_schema IS NULL THEN
    RAISE NOTICE 'PostGIS is not installed in this database.';
  ELSE
    IF ext_schema = 'extensions' THEN
      RAISE NOTICE 'PostGIS is installed in the intended schema: %', ext_schema;
    ELSE
      RAISE WARNING 'PostGIS is installed in schema: % (recommended: extensions). Moving requires drop/recreate.', ext_schema;
      RAISE NOTICE 'See docs/supabase/postgis_reinstall_in_extensions.sql for a guided plan (advanced, downtime, superuser).';
    END IF;
  END IF;
END$$;
