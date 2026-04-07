-- Robust, idempotent views for deriving org_id from loads and HOS logs
-- Run in Supabase SQL editor after base schema migrations. Safe to run multiple times.
-- Goals:
-- 1) v_loads_with_org never assumes non-existent columns. If loads.org_id exists → expose just l.*.
--    Else expose l.* plus org_id_derived (attempt best derivation, else NULL::uuid).
-- 2) v_hos_logs_with_org mirrors the above for hos_logs (derive via org_users if possible).
-- 3) Optional: add protective index on loads(status) if column exists.

-- Helper: returns true if a given column exists on a table
CREATE OR REPLACE FUNCTION public._col_exists(p_schema text, p_table text, p_column text)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = p_schema AND table_name = p_table AND column_name = p_column
  );
$$;

-- 1) v_loads_with_org (dynamic based on schema)
DO $$
DECLARE
  has_loads boolean;
  has_org_id boolean;
  col_owner boolean;
  col_poster boolean;
  col_broker boolean;
  col_carrier boolean;
  sel text;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='loads'
  ) INTO has_loads;

  IF NOT has_loads THEN
    -- Nothing to do if base table missing
    RETURN;
  END IF;

  SELECT public._col_exists('public','loads','org_id') INTO has_org_id;
  SELECT public._col_exists('public','loads','owner_org_id') INTO col_owner;
  SELECT public._col_exists('public','loads','poster_org_id') INTO col_poster;
  SELECT public._col_exists('public','loads','broker_org_id') INTO col_broker;
  SELECT public._col_exists('public','loads','carrier_org_id') INTO col_carrier;

  IF has_org_id THEN
    sel := 'CREATE OR REPLACE VIEW public.v_loads_with_org AS SELECT l.* FROM public.loads l';
  ELSE
    -- Choose best available column as org_id_derived; else NULL::uuid
    sel := 'CREATE OR REPLACE VIEW public.v_loads_with_org AS SELECT l.*';
    IF col_owner THEN
      sel := sel || ', l.owner_org_id AS org_id_derived';
    ELSIF col_poster THEN
      sel := sel || ', l.poster_org_id AS org_id_derived';
    ELSIF col_broker THEN
      sel := sel || ', l.broker_org_id AS org_id_derived';
    ELSIF col_carrier THEN
      sel := sel || ', l.carrier_org_id AS org_id_derived';
    ELSE
      sel := sel || ', NULL::uuid AS org_id_derived';
    END IF;
    sel := sel || ' FROM public.loads l';
  END IF;

  EXECUTE sel;
END $$;

-- 2) v_hos_logs_with_org (derive via org_users if possible)
DO $$
DECLARE
  has_hos boolean;
  has_org_id boolean;
  has_driver_user_id boolean;
  has_org_users boolean;
  sel text;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='hos_logs'
  ) INTO has_hos;

  IF NOT has_hos THEN
    RETURN;
  END IF;

  SELECT public._col_exists('public','hos_logs','org_id') INTO has_org_id;
  SELECT public._col_exists('public','hos_logs','driver_user_id') INTO has_driver_user_id;
  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='org_users'
  ) INTO has_org_users;

  IF has_org_id THEN
    sel := 'CREATE OR REPLACE VIEW public.v_hos_logs_with_org AS SELECT h.* FROM public.hos_logs h';
  ELSE
    sel := 'CREATE OR REPLACE VIEW public.v_hos_logs_with_org AS SELECT h.*';
    IF has_driver_user_id AND has_org_users THEN
      -- Join to org_users to derive org by driver_user_id if available
      sel := sel || ', ou.org_id AS org_id_derived FROM public.hos_logs h LEFT JOIN public.org_users ou ON ou.user_id = h.driver_user_id';
    ELSE
      sel := sel || ', NULL::uuid AS org_id_derived FROM public.hos_logs h';
    END IF;
  END IF;

  EXECUTE sel;
END $$;

-- 3) Optional protective index on loads(status)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='loads' AND column_name='status'
  ) THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_loads_status ON public.loads(status)';
  END IF;
END $$;

-- Cleanup helper is intentionally kept (harmless if left). To remove later:
-- DROP FUNCTION IF EXISTS public._col_exists(p_schema text, p_table text, p_column text);