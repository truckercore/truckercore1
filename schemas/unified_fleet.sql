-- Unified Fleet Schema for TruckerCore (Supabase / Postgres)
-- Migration file: schemas/unified_fleet.sql

-- Enable required extensions (if not already enabled in your project)
-- CREATE EXTENSION IF NOT EXISTS pgcrypto; -- for gen_random_uuid()

-- FLEETS (multi-tenant)
CREATE TABLE IF NOT EXISTS fleets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

-- USERS
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY,
  fleet_id UUID REFERENCES fleets(id),
  email TEXT NOT NULL UNIQUE,
  full_name TEXT,
  role TEXT NOT NULL, -- fleet_admin, dispatcher, driver, broker
  created_at TIMESTAMP DEFAULT NOW()
);

-- TRUCKS
CREATE TABLE IF NOT EXISTS trucks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fleet_id UUID REFERENCES fleets(id),
  vin TEXT UNIQUE,
  license_plate TEXT,
  make TEXT,
  model TEXT,
  year INT,
  status TEXT DEFAULT 'active',
  created_at TIMESTAMP DEFAULT NOW()
);

-- GPS PINGS
CREATE TABLE IF NOT EXISTS gps_pings (
  id BIGSERIAL PRIMARY KEY,
  truck_id UUID REFERENCES trucks(id),
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  speed DOUBLE PRECISION,
  event_time TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW()
);

-- MAINTENANCE EVENTS
CREATE TABLE IF NOT EXISTS maintenance_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  truck_id UUID REFERENCES trucks(id),
  type TEXT,
  odometer INT,
  description TEXT,
  event_time TIMESTAMP,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMP DEFAULT NOW()
);

-- FUEL TRANSACTIONS
CREATE TABLE IF NOT EXISTS fuel_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  truck_id UUID REFERENCES trucks(id),
  driver_id UUID REFERENCES users(id),
  gallons DOUBLE PRECISION,
  total_cost NUMERIC,
  location TEXT,
  fuel_time TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW()
);

-- LOADS
CREATE TABLE IF NOT EXISTS loads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fleet_id UUID REFERENCES fleets(id),
  truck_id UUID REFERENCES trucks(id),
  driver_id UUID REFERENCES users(id),
  status TEXT,
  pickup_location TEXT,
  dropoff_location TEXT,
  scheduled_pickup TIMESTAMP,
  scheduled_dropoff TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW()
);

-- DRIVER HOS
CREATE TABLE IF NOT EXISTS driver_hos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID REFERENCES users(id),
  truck_id UUID REFERENCES trucks(id),
  hos_status TEXT,
  log_time TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW()
);

-- INVOICES
CREATE TABLE IF NOT EXISTS invoices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fleet_id UUID REFERENCES fleets(id),
  load_id UUID REFERENCES loads(id),
  total NUMERIC,
  status TEXT DEFAULT 'pending',
  pdf_url TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- AUDIT LOG
CREATE TABLE IF NOT EXISTS audit_log (
  id BIGSERIAL PRIMARY KEY,
  table_name TEXT,
  record_id UUID,
  action TEXT,
  edited_by UUID REFERENCES users(id),
  old_values JSONB,
  new_values JSONB,
  edited_at TIMESTAMP DEFAULT NOW()
);

-- TODO: Add Row Level Security (RLS) policies for each table according to your multi-tenant model.
-- Example placeholders (uncomment and tailor in Supabase):
-- ALTER TABLE fleets ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "fleet_admins_read_own_fleet" ON fleets FOR SELECT
--   USING (EXISTS (SELECT 1 FROM users u WHERE u.id = auth.uid() AND u.fleet_id = fleets.id AND u.role = 'fleet_admin'));
