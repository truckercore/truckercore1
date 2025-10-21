-- Risk hardening migration bundle (2025-09)
-- Safe, additive changes to enforce status consistency, broker_id standardization hooks,
-- owner-operator improvements, marketplace audit columns, and indexes. Apply in a maintenance window.
-- Requires: audit_log table (present in schemas/unified_fleet.sql).

-- 1) loads.status canonicalization (use CHECK instead of enum to avoid view/type lock issues)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.constraint_column_usage c
    WHERE c.table_name = 'loads' AND c.column_name = 'status' AND c.constraint_name = 'loads_status_check')
  THEN
    EXECUTE 'ALTER TABLE loads
      ADD CONSTRAINT loads_status_check
      CHECK (status IN (''draft'',''assigned'',''in_transit'',''delivered'',''canceled''))';
  END IF;
END$$;

-- Optional: add status_v2 for zero-downtime swaps (leave commented for planned migrations)
-- ALTER TABLE loads ADD COLUMN IF NOT EXISTS status_v2 TEXT;
-- -- Backfill and repoint views/materialized views to status_v2, then swap and drop old column in a later migration.

-- 2) Owner-operator schema improvements
-- 2a) owner_ops: enforce 1:1 with users
ALTER TABLE owner_ops
  ADD CONSTRAINT IF NOT EXISTS owner_ops_user_unique UNIQUE (user_id);

-- 2b) owner_op_trips: cascade deletes when parent owner_op is removed
ALTER TABLE owner_op_trips
  DROP CONSTRAINT IF EXISTS owner_op_trips_owner_op_id_fkey,
  ADD CONSTRAINT owner_op_trips_owner_op_id_fkey
    FOREIGN KEY (owner_op_id) REFERENCES owner_ops(id) ON DELETE CASCADE;

-- 2c) owner_op_invoices & trip_expenses: cascade on trip delete
ALTER TABLE owner_op_invoices
  DROP CONSTRAINT IF EXISTS owner_op_invoices_trip_id_fkey,
  ADD CONSTRAINT owner_op_invoices_trip_id_fkey
    FOREIGN KEY (trip_id) REFERENCES owner_op_trips(id) ON DELETE CASCADE;

ALTER TABLE trip_expenses
  DROP CONSTRAINT IF EXISTS trip_expenses_trip_id_fkey,
  ADD CONSTRAINT trip_expenses_trip_id_fkey
    FOREIGN KEY (trip_id) REFERENCES owner_op_trips(id) ON DELETE CASCADE;

-- 2d) trip_expenses: type check + index on (trip_id, created_at DESC)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.constraint_column_usage c
    WHERE c.table_name = 'trip_expenses' AND c.constraint_name = 'trip_expenses_type_check')
  THEN
    EXECUTE 'ALTER TABLE trip_expenses ADD CONSTRAINT trip_expenses_type_check
            CHECK (type IN (''fuel'',''tolls'',''repair'',''insurance'',''factoring'',''food'',''other''))';
  END IF;
END$$;
CREATE INDEX IF NOT EXISTS idx_trip_expenses_trip_created_desc ON trip_expenses(trip_id, created_at DESC);

-- 2e) owner_op_invoices: enhance amounts and status; optional invoice_number uniqueness
ALTER TABLE owner_op_invoices
  ADD COLUMN IF NOT EXISTS subtotal NUMERIC,
  ADD COLUMN IF NOT EXISTS tax NUMERIC,
  ADD COLUMN IF NOT EXISTS total NUMERIC,
  ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS invoice_number TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS uq_owner_op_invoice_number ON owner_op_invoices(invoice_number) WHERE invoice_number IS NOT NULL;

-- 2f) logbook_entries: enforce event_type and index (owner_op_id, event_time DESC)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.constraint_column_usage c
    WHERE c.table_name = 'logbook_entries' AND c.constraint_name = 'logbook_entries_event_type_check')
  THEN
    EXECUTE 'ALTER TABLE logbook_entries ADD CONSTRAINT logbook_entries_event_type_check
            CHECK (event_type IN (''driving'',''on_duty'',''off_duty'',''sleeper''))';
  END IF;
END$$;
CREATE INDEX IF NOT EXISTS idx_logbook_owner_time_desc ON logbook_entries(owner_op_id, event_time DESC);

-- 2g) owner_op_maintenance_events: type check + helpful indexes
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.constraint_column_usage c
    WHERE c.table_name = 'owner_op_maintenance_events' AND c.constraint_name = 'owner_op_maint_type_check')
  THEN
    EXECUTE 'ALTER TABLE owner_op_maintenance_events ADD CONSTRAINT owner_op_maint_type_check
            CHECK (type IN (''oil_change'',''tire'',''inspection'',''repairs'',''other''))';
  END IF;
END$$;
CREATE INDEX IF NOT EXISTS idx_owner_op_maint_owner_time ON owner_op_maintenance_events(owner_op_id, scheduled_time);
CREATE INDEX IF NOT EXISTS idx_owner_op_maint_owner_vin_created ON owner_op_maintenance_events(owner_op_id, truck_vin, created_at);

-- 3) Marketplace loads: search and AI audit fields
ALTER TABLE marketplace_loads
  ADD COLUMN IF NOT EXISTS deadhead_miles NUMERIC,
  ADD COLUMN IF NOT EXISTS rank_score NUMERIC,
  ADD COLUMN IF NOT EXISTS reason TEXT[];
CREATE INDEX IF NOT EXISTS idx_mkt_loads_status_pickup_desc ON marketplace_loads(status, pickup_time DESC);
CREATE INDEX IF NOT EXISTS idx_mkt_loads_equipment_pickup ON marketplace_loads(equipment_type, pickup_time);

-- 4) Broker key standardization note
-- If any tables use brokerage_id, rename to broker_id with a separate, tested migration. No occurrences were found in repo SQL at commit time.
-- Example (execute only where needed):
-- ALTER TABLE some_table RENAME COLUMN brokerage_id TO broker_id;
-- CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_some_table_broker ON some_table(broker_id);

-- 5) RLS hardening guidance (placeholders; tailor in Supabase console/migrations)
-- Example strict policies:
-- ALTER TABLE loads ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY loads_tenant_isolation ON loads FOR ALL
--   USING (fleet_id = current_setting(''request.jwt.claims''::text)::jsonb ->> ''fleet_id'')
--   WITH CHECK (fleet_id = current_setting(''request.jwt.claims''::text)::jsonb ->> ''fleet_id'');

-- 6) Migration notes for views/type conflicts
-- Use add status_v2 (TEXT + CHECK), backfill, repoint dependent views to status_v2, then swap. Avoid direct enum type changes if views depend on the column.

-- 7) Minimal audit example trigger (optional, commented)
-- CREATE OR REPLACE FUNCTION tg_audit_summary() RETURNS trigger AS $$
-- BEGIN
--   INSERT INTO audit_log(table_name, record_id, action, edited_by, old_values, new_values)
--   VALUES (TG_TABLE_NAME, NEW.id, TG_OP, NULL, to_jsonb(OLD), to_jsonb(NEW));
--   RETURN NEW;
-- END; $$ LANGUAGE plpgsql;

-- 8) Legacy index cleanup (brokerage_id drift)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'public' AND indexname = 'idx_loads_brokerage_id') THEN
    EXECUTE 'DROP INDEX CONCURRENTLY IF EXISTS idx_loads_brokerage_id';
  END IF;
END$$;

-- 9) Lint query for non-canonical load statuses (run manually to surface drift)
-- SELECT status, COUNT(*) FROM loads WHERE status NOT IN ('draft','assigned','in_transit','delivered','canceled') GROUP BY 1 ORDER BY 2 DESC;
