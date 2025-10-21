-- Phase A: Canonical statuses, broker_id standardization, indexes, and RLS for owner-ops
-- Safe to run multiple times; includes guards for existing objects.
-- Apply in Supabase SQL editor or via CLI migrations in a maintenance window.

-- 1) Canonical load statuses (single source of truth)
DO $$
BEGIN
  -- Drop old CHECK if name differs, then (re)add canonical constraint
  IF EXISTS (
    SELECT 1 FROM information_schema.constraint_column_usage c
    WHERE c.table_name = 'loads' AND c.column_name = 'status' AND c.constraint_name = 'loads_status_check'
  ) THEN
    -- Ensure it enforces the right set by dropping and re-adding
    EXECUTE 'ALTER TABLE public.loads DROP CONSTRAINT IF EXISTS loads_status_check';
  END IF;
  -- Re-add with canonical set
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.constraint_column_usage c
    WHERE c.table_name = 'loads' AND c.column_name = 'status' AND c.constraint_name = 'loads_status_check'
  ) THEN
    EXECUTE $$ALTER TABLE public.loads
      ADD CONSTRAINT loads_status_check
      CHECK (status IN ('draft','assigned','in_transit','delivered','canceled'))$$;
  END IF;
  -- Default to 'draft' if not already
  PERFORM 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='loads' AND column_name='status' AND column_default LIKE '%draft%';
  IF NOT FOUND THEN
    EXECUTE 'ALTER TABLE public.loads ALTER COLUMN status SET DEFAULT ''draft''';
  END IF;
END$$;

-- 2) Standardize broker_id on loads and policy
-- Add broker_id if missing
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='loads' AND column_name='broker_id'
  ) THEN
    EXECUTE 'ALTER TABLE public.loads ADD COLUMN broker_id uuid';
  END IF;
END$$;

-- Helper: current_broker_id() from JWT claims (expects { "broker_id": "uuid" })
CREATE OR REPLACE FUNCTION public.current_broker_id()
RETURNS uuid
LANGUAGE plpgsql STABLE AS $$
DECLARE
  claims jsonb;
  bid text;
BEGIN
  BEGIN
    claims := current_setting('request.jwt.claims', true)::jsonb;
  EXCEPTION WHEN others THEN
    RETURN NULL;
  END;
  IF claims IS NULL THEN RETURN NULL; END IF;
  bid := claims->>'broker_id';
  IF bid IS NULL OR bid = '' THEN RETURN NULL; END IF;
  RETURN bid::uuid;
END$$;

-- Enable RLS on loads (if you use fleet/org scoping instead, adjust accordingly)
ALTER TABLE IF EXISTS public.loads ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS loads_broker_rw ON public.loads;
CREATE POLICY loads_broker_rw ON public.loads
  FOR ALL TO authenticated
  USING (broker_id = public.current_broker_id())
  WITH CHECK (broker_id = public.current_broker_id());

-- 3) Indexes for common filters
-- a) loads (broker_id, status)
CREATE INDEX IF NOT EXISTS idx_loads_broker_status ON public.loads (broker_id, status);

-- b) loads assigned driver/time index
-- Some schemas use assigned_driver_id + pickup_at; others use driver_id + scheduled_pickup.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='loads' AND column_name='assigned_driver_id'
  ) AND EXISTS (
    SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='loads' AND column_name='pickup_at'
  ) THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_loads_assigned_driver ON public.loads (assigned_driver_id, pickup_at DESC)';
  ELSIF EXISTS (
    SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='loads' AND column_name='driver_id'
  ) AND EXISTS (
    SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='loads' AND column_name='scheduled_pickup'
  ) THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_loads_driver_scheduled_pickup ON public.loads (driver_id, scheduled_pickup DESC)';
  END IF;
END$$;

-- c) owner-op domain indexes to match common queries
-- If your schema uses owner_op_trips/owner_op_invoices, create indexes accordingly.
CREATE INDEX IF NOT EXISTS idx_owner_op_trips_owner_time ON public.owner_op_trips (owner_op_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_trip_expenses_trip_time ON public.trip_expenses (trip_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_owner_op_invoices_trip_time ON public.owner_op_invoices (trip_id, created_at DESC);

-- 4) Wire RLS for owner_ops domain
-- Helper: resolve current owner_op_id for auth user
CREATE OR REPLACE FUNCTION public.current_owner_op_id()
RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT id FROM public.owner_ops WHERE user_id = (SELECT auth.uid()) LIMIT 1
$$;

-- Enable RLS
ALTER TABLE IF EXISTS public.owner_ops ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.owner_op_trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.trip_expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.owner_op_invoices ENABLE ROW LEVEL SECURITY;

-- Policies
DROP POLICY IF EXISTS owner_ops_rw ON public.owner_ops;
CREATE POLICY owner_ops_rw ON public.owner_ops
  FOR ALL TO authenticated
  USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS owner_op_trips_ownerop_rw ON public.owner_op_trips;
CREATE POLICY owner_op_trips_ownerop_rw ON public.owner_op_trips
  FOR ALL TO authenticated
  USING (owner_op_id = public.current_owner_op_id())
  WITH CHECK (owner_op_id = public.current_owner_op_id());

DROP POLICY IF EXISTS trip_expenses_ownerop_rw ON public.trip_expenses;
CREATE POLICY trip_expenses_ownerop_rw ON public.trip_expenses
  FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.owner_op_trips t WHERE t.id = trip_expenses.trip_id AND t.owner_op_id = public.current_owner_op_id()
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.owner_op_trips t WHERE t.id = trip_expenses.trip_id AND t.owner_op_id = public.current_owner_op_id()
  ));

DROP POLICY IF EXISTS owner_op_invoices_ownerop_rw ON public.owner_op_invoices;
CREATE POLICY owner_op_invoices_ownerop_rw ON public.owner_op_invoices
  FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.owner_op_trips t WHERE t.id = owner_op_invoices.trip_id AND t.owner_op_id = public.current_owner_op_id()
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.owner_op_trips t WHERE t.id = owner_op_invoices.trip_id AND t.owner_op_id = public.current_owner_op_id()
  ));

-- 5) Verification helpers (run manually)
-- SELECT DISTINCT status FROM public.loads ORDER BY 1;
-- SELECT policyname, qual, with_check FROM pg_policies WHERE tablename IN ('loads','owner_ops','owner_op_trips','trip_expenses','owner_op_invoices') ORDER BY tablename, policyname;
-- SELECT relname, relrowsecurity FROM pg_class WHERE relname IN ('loads','owner_ops','owner_op_trips','trip_expenses','owner_op_invoices');
-- \d+ public.loads  -- confirm broker_id presence and index usage via EXPLAIN on your hot queries.
