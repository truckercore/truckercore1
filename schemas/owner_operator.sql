-- Owner-Operator Feature Schema Additions for TruckerCore (Supabase/Postgres)
-- Migration file: schemas/owner_operator.sql
-- Safe to run multiple times; uses IF NOT EXISTS where applicable. Review notes about potential naming overlaps.

-- NOTE ON EXISTING TABLES
-- This project already defines some tables like invoices and maintenance_events in schemas/unified_fleet.sql.
-- The owner-operator feature set introduces similar concepts but scoped to owner-operators. To avoid conflicts:
--  - We use new tables that do not collide with existing names where possible.
--  - For overlapping names shown in the product brief (e.g., invoices, maintenance_events), we either:
--      a) create owner-op-specific tables with distinct names (recommended), or
--      b) extend existing tables with nullable owner_op_id columns (requires migration planning).
-- This migration opts for distinct owner-op-specific tables to avoid breaking existing data flows.

-- Enable extension if needed for gen_random_uuid()
-- CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- OWNER-OPERATOR PROFILE
CREATE TABLE IF NOT EXISTS owner_ops (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    business_name TEXT,
    premium_tier BOOLEAN DEFAULT FALSE,
    trucks_managed INT DEFAULT 1,
    stripe_sub_id TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- MARKETPLACE LOADS (for smart matching)
CREATE TABLE IF NOT EXISTS marketplace_loads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- Assuming a brokers table exists; if not, change FK to users(id) or remove
    posted_by_broker_id UUID,
    equipment_type TEXT,
    origin TEXT,
    destination TEXT,
    pickup_time TIMESTAMP,
    pay NUMERIC,
    currency TEXT DEFAULT 'USD',
    min_lanes TEXT[],
    status TEXT DEFAULT 'open'
);

-- ACCEPTED LOADS / TRIPS
CREATE TABLE IF NOT EXISTS owner_op_trips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_op_id UUID REFERENCES owner_ops(id),
    marketplace_load_id UUID REFERENCES marketplace_loads(id),
    status TEXT DEFAULT 'planned',
    trip_plan JSONB,
    deadhead_miles NUMERIC,
    created_at TIMESTAMP DEFAULT NOW()
);

-- CUSTOMER-SUBMITTED PORTAL LOADS
CREATE TABLE IF NOT EXISTS customer_portal_loads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_op_id UUID REFERENCES owner_ops(id),
    shipper_id UUID, -- optional FK to shippers if exists
    status TEXT DEFAULT 'pending',
    load_details JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);

-- EXPENSES/INCOME per trip
CREATE TABLE IF NOT EXISTS trip_expenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID REFERENCES owner_op_trips(id),
    type TEXT,
    amount NUMERIC,
    currency TEXT DEFAULT 'USD',
    receipt_url TEXT,
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- DIGITAL INVOICES (Owner-Op specific to avoid collision with existing invoices)
CREATE TABLE IF NOT EXISTS owner_op_invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID REFERENCES owner_op_trips(id),
    pdf_url TEXT,
    due_date TIMESTAMP,
    paid BOOLEAN DEFAULT FALSE,
    sent_to TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- LOGBOOK (HOS)
CREATE TABLE IF NOT EXISTS logbook_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_op_id UUID REFERENCES owner_ops(id),
    event_type TEXT,
    event_time TIMESTAMP DEFAULT NOW(),
    duration_mins INT,
    location TEXT,
    violation_alert BOOLEAN DEFAULT FALSE
);

-- MAINTENANCE + REMINDERS (Owner-Op specific to avoid collision)
CREATE TABLE IF NOT EXISTS owner_op_maintenance_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_op_id UUID REFERENCES owner_ops(id),
    truck_vin TEXT,
    type TEXT,
    odometer INT,
    scheduled_time TIMESTAMP,
    completed BOOLEAN DEFAULT FALSE,
    cost NUMERIC,
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- AI COACHING LOGS
CREATE TABLE IF NOT EXISTS ai_coaching_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_op_id UUID REFERENCES owner_ops(id),
    topic TEXT,
    ai_tip TEXT,
    provided_at TIMESTAMP DEFAULT NOW()
);

-- Indexes to improve common queries
CREATE INDEX IF NOT EXISTS idx_owner_ops_user ON owner_ops(user_id);
CREATE INDEX IF NOT EXISTS idx_mkt_loads_status_time ON marketplace_loads(status, pickup_time);
CREATE INDEX IF NOT EXISTS idx_owner_op_trips_owner ON owner_op_trips(owner_op_id);
CREATE INDEX IF NOT EXISTS idx_trip_expenses_trip ON trip_expenses(trip_id);
CREATE INDEX IF NOT EXISTS idx_logbook_owner_time ON logbook_entries(owner_op_id, event_time);
CREATE INDEX IF NOT EXISTS idx_owner_op_maint_owner_time ON owner_op_maintenance_events(owner_op_id, scheduled_time);

-- RLS PLACEHOLDERS (uncomment/tailor in Supabase)
-- ALTER TABLE owner_ops ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY owner_ops_self ON owner_ops FOR SELECT USING (user_id = auth.uid());
-- ... Add similar policies for other tables, scoping by owner_op_id derived from current user.
