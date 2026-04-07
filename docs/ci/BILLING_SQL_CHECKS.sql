-- docs/ci/BILLING_SQL_CHECKS.sql
-- CI SQL lint/checks for billing domain. Designed to be safe across environments.
-- Usage: psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f docs/ci/BILLING_SQL_CHECKS.sql

-- 1) Verify RLS enabled on billing tables IF they exist
DO $$
DECLARE t text; rls boolean; 
BEGIN
  FOR t IN SELECT unnest(ARRAY['billing_invoices','billing_entitlements','billing_seats','billing_reports']) LOOP
    IF to_regclass('public.'||t) IS NOT NULL THEN
      SELECT c.relrowsecurity INTO rls
      FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='public' AND c.relname=t;
      IF NOT rls THEN
        RAISE EXCEPTION 'RLS disabled on %', t;
      END IF;
    END IF;
  END LOOP;
END$$;

-- 2) Entitlements consistency (only when both sources exist)
-- Expect: entitled seats >= provisioned seats per org, else warn/raise.
DO $$
DECLARE diff int; 
BEGIN
  IF to_regclass('public.billing_entitlements') IS NOT NULL AND to_regclass('public.billing_seats') IS NOT NULL THEN
    SELECT count(*) INTO diff FROM (
      SELECT e.org_id
      FROM public.billing_entitlements e
      LEFT JOIN public.billing_seats s ON s.org_id=e.org_id
      WHERE COALESCE(e.entitled_seats,0) < COALESCE(s.active_seats,0)
    ) q;
    IF diff > 0 THEN
      RAISE EXCEPTION 'Found % orgs where provisioned seats exceed entitlements', diff;
    END IF;
  END IF;
END$$;

-- 3) RPC signatures existence/shape (best effort)
-- If reconcile function exists, ensure it takes a single org uuid or runs global when org is null
DO $$
DECLARE cnt int; 
BEGIN
  SELECT count(*) INTO cnt FROM pg_proc p
  JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND p.proname='reconcile_billing';
  IF cnt > 0 THEN
    -- Check there is at least one reconcile_billing(uuid) or reconcile_billing()
    PERFORM 1 FROM pg_proc p
      JOIN pg_namespace n ON n.oid=p.pronamespace
      WHERE n.nspname='public' AND p.proname='reconcile_billing' AND (
        pg_get_function_identity_arguments(p.oid)='org uuid' OR pg_get_function_identity_arguments(p.oid)='' 
      );
    IF NOT FOUND THEN
      RAISE EXCEPTION 'reconcile_billing exists but signature is unexpected (expected () or (org uuid))';
    END IF;
  END IF;
END$$;
