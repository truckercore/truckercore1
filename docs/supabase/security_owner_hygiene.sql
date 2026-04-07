-- docs/supabase/security_owner_hygiene.sql
-- One-time owner/grant hygiene for RPC functions and target tables.
-- Goals:
--  - Create a dedicated, non-superuser owner role (app_owner) and make it the owner of
--    sensitive functions and tables. This enables intentional RLS bypass only where needed
--    via SECURITY DEFINER, rather than broad superuser privileges.
--  - Revoke PUBLIC EXECUTE from functions by default and grant narrowly to
--    the roles your app uses (authenticated, service_role). Do not grant to anon unless intended.
--  - If a function must bypass RLS, mark it SECURITY DEFINER and lock search_path
--    to a safe list to avoid dynamic SQL path poisoning. Add comments documenting the intent.
--  - Keep error messages application-level; avoid leaking schema internals from the DB layer.

begin; -- wrap in a transaction for safety

-- 1) Dedicated owner role (no login, no superuser)
create role app_owner nologin; -- idempotent if exists handled below
-- Ensure existence idempotently
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'app_owner') then
    create role app_owner nologin;
  end if;
end $$;

-- 2) Transfer ownership of target tables to app_owner if they exist.
--    These are the tables typically touched by the safe-send flow and offline ingestion.
--    Adjust the list to your environment as needed.
DO $$
DECLARE
  t text;
  tables text[] := ARRAY[
    'dispatch_actions',
    'dispatch_safe_staging',
    'mobile_offline_queue',
    'loads',
    'vehicle_positions'
  ];
BEGIN
  FOREACH t IN ARRAY tables LOOP
    IF EXISTS (
      SELECT 1 FROM information_schema.tables
      WHERE table_schema = 'public' AND table_name = t
    ) THEN
      EXECUTE format('ALTER TABLE public.%I OWNER TO app_owner', t);
      -- Keep existing RLS policies; SECURITY DEFINER functions owned by app_owner may bypass RLS.
      -- That bypass is intentional only when the function comments below say so.
    END IF;
  END LOOP;
END $$;

-- 3) Find and secure functions by name regardless of signature.
--    We expect at least stage_safe_send, undo_action, and optionally confirm_and_apply.
--    For each function:
--      - Transfer owner to app_owner
--      - Mark SECURITY DEFINER (intentional RLS bypass when touching owned tables)
--      - Lock search_path
--      - Revoke PUBLIC execute; grant to authenticated and service_role
DO $$
DECLARE
  fn RECORD;
  target_names text[] := ARRAY['stage_safe_send','undo_action','confirm_and_apply'];
BEGIN
  FOR fn IN
    SELECT p.oid, n.nspname AS schema, p.proname AS name,
           pg_get_function_identity_arguments(p.oid) AS args
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = ANY(target_names)
  LOOP
    -- Transfer ownership
    EXECUTE format('ALTER FUNCTION %I.%I(%s) OWNER TO app_owner', fn.schema, fn.name, fn.args);

    -- Mark SECURITY DEFINER and lock search_path (defense-in-depth for dynamic SQL)
    EXECUTE format('ALTER FUNCTION %I.%I(%s) SECURITY DEFINER', fn.schema, fn.name, fn.args);
    EXECUTE format('ALTER FUNCTION %I.%I(%s) SET search_path = public, pg_temp', fn.schema, fn.name, fn.args);

    -- Document intent in a COMMENT (visible to DBAs)
    EXECUTE format(
      $$COMMENT ON FUNCTION %I.%I(%s) IS 'APP_GUARD: This RPC runs as app_owner (SECURITY DEFINER). If it writes to tables owned by app_owner, it may bypass RLS intentionally. Keep function body stamping auth.uid()/jwt.claims for identity; do not trust client-supplied org_id/user_id.'$$,
      fn.schema, fn.name, fn.args
    );

    -- Narrow grants
    EXECUTE format('REVOKE ALL ON FUNCTION %I.%I(%s) FROM PUBLIC', fn.schema, fn.name, fn.args);
    -- Avoid granting to anon unless explicitly needed
    EXECUTE format('REVOKE ALL ON FUNCTION %I.%I(%s) FROM anon', fn.schema, fn.name, fn.args);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %I.%I(%s) TO authenticated', fn.schema, fn.name, fn.args);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %I.%I(%s) TO service_role', fn.schema, fn.name, fn.args);
  END LOOP;
END $$;

-- 4) Default privileges for future functions owned by app_owner
--    Prevent accidental PUBLIC EXECUTE and grant only to allowed roles.
DO $$ begin
  -- Revoke PUBLIC by default
  execute 'ALTER DEFAULT PRIVILEGES FOR ROLE app_owner IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC';
  execute 'ALTER DEFAULT PRIVILEGES FOR ROLE app_owner IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM anon';
  -- Grant narrowly
  execute 'ALTER DEFAULT PRIVILEGES FOR ROLE app_owner IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO authenticated';
  execute 'ALTER DEFAULT PRIVILEGES FOR ROLE app_owner IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO service_role';
end $$;

-- 5) Optional: Ensure application-level error codes are used.
-- NOTE: Actual error-raising must be inside the function bodies. Use RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'AUTH_REQUIRED';
-- We cannot change function bodies here, but we document the convention to avoid leaking schema details.

commit;
