-- API Exposure Setup for Supabase (Postgres 15+)
-- Purpose: Expose only the api schema via PostgREST; keep base tables in public secured by RLS.
-- Safe to run multiple times. Run after base schemas and tables are created.
-- This script:
--  - Ensures api schema exists.
--  - Grants USAGE on api to anon and authenticated; revokes CREATE from untrusted roles.
--  - Optionally grants CREATE on api only to admin/deploy roles if present.
--  - Sets default privileges in api for typical model: anon=SELECT, authenticated=SELECT,CRUD.
--  - Creates api views with security_invoker=true so base-table RLS applies.
--  - Grants privileges on api objects to intended roles.
--  - Leaves underlying public tables with RLS enabled and policies enforced.

-- 0) Create api schema if missing
CREATE SCHEMA IF NOT EXISTS api;

-- 1) Basic privileges on schema api
-- Grant USAGE so roles can access objects; do not allow CREATE to anon/authenticated.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    EXECUTE 'GRANT USAGE ON SCHEMA api TO anon';
    EXECUTE 'REVOKE CREATE ON SCHEMA api FROM anon';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    EXECUTE 'GRANT USAGE ON SCHEMA api TO authenticated';
    EXECUTE 'REVOKE CREATE ON SCHEMA api FROM authenticated';
  END IF;
  -- Also revoke from PUBLIC just in case
  EXECUTE 'REVOKE CREATE ON SCHEMA api FROM PUBLIC';

  -- Allow CREATE to administrative role(s) if present
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'postgres') THEN
    EXECUTE 'GRANT CREATE ON SCHEMA api TO postgres';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin') THEN
    EXECUTE 'GRANT CREATE ON SCHEMA api TO supabase_admin';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
    EXECUTE 'GRANT USAGE ON SCHEMA api TO service_role';
    -- service_role usually doesn't need CREATE, but grant if your deploy relies on it
  END IF;
END$$;

-- 2) Default privileges inside api
-- New tables/views created by admin should by default be readable by anon and CRUD by authenticated
-- Adjust to your desired model.
DO $$
DECLARE
  grant_owner text := current_user; -- change to your deploy role if needed
BEGIN
  -- Only affect future objects created by the current user in schema api
  EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA api GRANT SELECT ON TABLES TO anon', grant_owner);
  EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA api GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO authenticated', grant_owner);
  EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA api GRANT USAGE, SELECT ON SEQUENCES TO authenticated', grant_owner);
END$$;

-- 3) Ensure RLS on base tables (examples). Adjust/extend as needed.
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='stations') THEN
    EXECUTE 'ALTER TABLE public.stations ENABLE ROW LEVEL SECURITY';
  END IF;
END $$;

-- 4) Create API views (examples). Use WITH (security_invoker=true) so base-table RLS applies.
-- 4a) api.stations view
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema=''public'' AND table_name=''stations'') THEN
    EXECUTE $$
      CREATE OR REPLACE VIEW api.stations
      WITH (security_invoker=true)
      AS
      SELECT id, name, lat, lng, open, created_at
      FROM public.stations
    $$;
  END IF;
END $$;

-- 4b) api.truck_current view mirrors public.v_truck_current if it exists
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.views WHERE table_schema='public' AND table_name='v_truck_current') THEN
    EXECUTE $$
      CREATE OR REPLACE VIEW api.truck_current
      WITH (security_invoker=true)
      AS
      SELECT * FROM public.v_truck_current
    $$;
  END IF;
END $$;

-- 4c) api.truck_current_positions_geo view mirrors public.v_truck_current_positions_geo if it exists
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.views WHERE table_schema='public' AND table_name='v_truck_current_positions_geo') THEN
    EXECUTE $$
      CREATE OR REPLACE VIEW api.truck_current_positions_geo
      WITH (security_invoker=true)
      AS
      SELECT * FROM public.v_truck_current_positions_geo
    $$;
  END IF;
END $$;

-- 5) Grants on API views/tables to roles
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.views WHERE table_schema='api' AND table_name='stations') THEN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname='anon') THEN
      EXECUTE 'GRANT SELECT ON api.stations TO anon';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN
      EXECUTE 'GRANT SELECT, INSERT, UPDATE, DELETE ON api.stations TO authenticated';
    END IF;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.views WHERE table_schema='api' AND table_name='truck_current') THEN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname='anon') THEN
      EXECUTE 'GRANT SELECT ON api.truck_current TO anon';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN
      EXECUTE 'GRANT SELECT ON api.truck_current TO authenticated';
    END IF;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.views WHERE table_schema='api' AND table_name='truck_current_positions_geo') THEN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname='anon') THEN
      EXECUTE 'GRANT SELECT ON api.truck_current_positions_geo TO anon';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN
      EXECUTE 'GRANT SELECT ON api.truck_current_positions_geo TO authenticated';
    END IF;
  END IF;
END $$;

-- 6) Reminder (manual step): In Supabase API settings, set "Exposed schemas" to: api (and any others like auth, storage) and remove public.
-- Verification:
--   SELECT table_schema, table_name FROM information_schema.tables WHERE table_schema='api' ORDER BY 1,2;
--   SELECT table_schema, table_name FROM information_schema.views WHERE table_schema='api' ORDER BY 1,2;
--   -- Check privileges:
--   SELECT table_schema, table_name, privilege_type, grantee
--   FROM information_schema.table_privileges WHERE table_schema='api' ORDER BY 1,2,3,4;
