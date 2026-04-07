-- Reinstall PostGIS into a dedicated schema (extensions)
-- Advanced operation: downtime required, superuser required. READ CAREFULLY.
-- This script is a guided, commented sequence. Execute step-by-step manually.
-- Do NOT run blindly in production.
--
-- Why: Some teams prefer to place extensions in a dedicated schema (e.g., extensions)
-- to keep the public schema minimal. PostGIS must be created in the target schema at
-- install time; it cannot be moved after creation.
--
-- Prerequisites and risks:
-- - Requires superuser (or a role with equivalent powers to drop/create extension and adjust ownerships).
-- - This can cascade-drop dependent objects if you use DROP EXTENSION ... CASCADE.
-- - Plan maintenance/downtime. Ensure backups and PITR are verified.
-- - Consider whether this is necessary: If your API exposure excludes public and you
--   don’t directly expose PostGIS objects, this change is optional and risky.
--
-- High-level sequence:
--  1) Verify superuser and environment readiness
--  2) Create schema extensions (if missing)
--  3) Inspect current PostGIS installation and dependencies
--  4) Drop PostGIS (optionally with CASCADE after reviewing deps)
--  5) Recreate PostGIS in schema extensions
--  6) Recreate/repair dependent objects and verify
--
-- 0) Safety: Print current user and version
\echo 'Current user and version:'
SELECT current_user AS current_user, version() AS pg_version;

-- 1) Verify role capabilities (best-effort checks)
\echo 'Checking if current role is superuser (requires access to pg_authid/pg_roles)...'
SELECT r.rolname, r.rolsuper FROM pg_roles r WHERE r.rolname = current_user;

-- 2) Create target schema if needed
CREATE SCHEMA IF NOT EXISTS extensions;

-- 3) Inspect current PostGIS installation
\echo 'Current PostGIS installation (if any):'
SELECT extname, n.nspname AS ext_schema
FROM pg_extension e
JOIN pg_namespace n ON n.oid = e.extnamespace
WHERE extname IN ('postgis','postgis_raster','postgis_topology')
ORDER BY extname;

\echo 'Objects referencing postgis extension (sample) – review before proceeding:'
SELECT d.objid::regclass AS dependent_object, d.refobjid::regclass AS referenced
FROM pg_depend d
JOIN pg_extension e ON e.oid = d.refobjid
WHERE e.extname = 'postgis'
LIMIT 50;

-- IMPORTANT: Stop here and review dependencies. If you have user-defined objects
-- that depend on PostGIS types/functions in public schema, plan to recreate them.
--
-- 4) Drop PostGIS from current schema
-- WARNING: This requires superuser and may need CASCADE. Only proceed if you fully
-- understand the impact. Uncomment exactly one of the following lines to execute.
--
-- DROP EXTENSION postgis; -- preferred if no dependent objects
-- DROP EXTENSION postgis CASCADE; -- risky; drops dependents, you must recreate them
-- Optional: also drop ancillary extensions if you use them and intend to reinstall:
-- DROP EXTENSION postgis_raster CASCADE;
-- DROP EXTENSION postgis_topology CASCADE;

-- 5) Recreate PostGIS in the new schema
-- You must create the extension in the target schema at install time.
-- Run only after step 4 succeeded.
--
-- CREATE EXTENSION postgis SCHEMA extensions WITH VERSION default; -- uncomment to run
-- Optionally reinstall related extensions:
-- CREATE EXTENSION postgis_raster SCHEMA extensions;
-- CREATE EXTENSION postgis_topology SCHEMA extensions;

-- 6) Verify installation schema
\echo 'Verify PostGIS is now in extensions schema:'
SELECT extname, n.nspname AS ext_schema
FROM pg_extension e
JOIN pg_namespace n ON n.oid = e.extnamespace
WHERE extname IN ('postgis','postgis_raster','postgis_topology')
ORDER BY extname;

-- 7) Post-steps: recreate dependent objects and validate functionality
-- - Recreate views/functions that referenced PostGIS objects if they were dropped.
-- - Re-run migrations that add indexes or columns of PostGIS types.
-- - Re-run CI checks and smoke tests.

-- Optional: Grant convenience USAGE on extensions schema to application roles
-- (read-only access to types/functions; adjust to your threat model)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'extensions') THEN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
      EXECUTE 'GRANT USAGE ON SCHEMA extensions TO anon';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
      EXECUTE 'GRANT USAGE ON SCHEMA extensions TO authenticated';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
      EXECUTE 'GRANT USAGE ON SCHEMA extensions TO service_role';
    END IF;
  END IF;
END$$;

-- Rollback guidance:
-- - If something fails after dropping PostGIS, restore from backup or PITR.
-- - If you recreated in the wrong schema, drop again and recreate with the schema clause.
--
-- Notes:
-- - On managed platforms (e.g., Supabase), you likely do NOT have superuser and cannot
--   perform steps 4–5. In that case, prefer the minimal shielding approach and ensure
--   your API only exposes the api schema. See minimal shielding script in this repo:
--   docs/supabase/postgis_minimal_shielding.sql
