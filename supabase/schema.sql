-- Driver Status Table
CREATE TABLE IF NOT EXISTS driver_status (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status TEXT NOT NULL CHECK (status IN ('on_duty', 'off_duty', 'driving', 'sleeper')),
  status_changed_at TIMESTAMPTZ DEFAULT NOW(),
  drive_time_left NUMERIC(5,2),
  shift_time_left NUMERIC(5,2),
  cycle_time_left NUMERIC(5,2),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(driver_id)
);

-- Loads Table
CREATE TABLE IF NOT EXISTS loads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  load_number TEXT NOT NULL UNIQUE,
  driver_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  vehicle_id UUID,
  fleet_id UUID,
  status TEXT NOT NULL CHECK (status IN ('pending', 'assigned', 'in_transit', 'delivered', 'cancelled')),
  pickup_location TEXT NOT NULL,
  delivery_location TEXT NOT NULL,
  pickup_time TIMESTAMPTZ,
  delivery_time TIMESTAMPTZ,
  eta TIMESTAMPTZ,
  distance NUMERIC(10,2),
  rate NUMERIC(10,2),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- HOS Records Table
CREATE TABLE IF NOT EXISTS hos_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  drive_time NUMERIC(5,2) DEFAULT 0,
  on_duty_time NUMERIC(5,2) DEFAULT 0,
  off_duty_time NUMERIC(5,2) DEFAULT 0,
  cycle_time NUMERIC(5,2) DEFAULT 0,
  max_drive_time NUMERIC(5,2) DEFAULT 11,
  max_shift_time NUMERIC(5,2) DEFAULT 14,
  max_cycle_time NUMERIC(5,2) DEFAULT 70,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(driver_id, date)
);

-- Vehicles Table
CREATE TABLE IF NOT EXISTS vehicles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fleet_id UUID NOT NULL,
  vehicle_number TEXT NOT NULL,
  make TEXT,
  model TEXT,
  year INTEGER,
  vin TEXT,
  license_plate TEXT,
  status TEXT NOT NULL CHECK (status IN ('active', 'inactive', 'maintenance', 'idle')),
  current_driver_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  current_location TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Fleets Table
CREATE TABLE IF NOT EXISTS fleets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  org_id UUID NOT NULL,
  manager_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE driver_status ENABLE ROW LEVEL SECURITY;
ALTER TABLE loads ENABLE ROW LEVEL SECURITY;
ALTER TABLE hos_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE fleets ENABLE ROW LEVEL SECURITY;

-- RLS Policies for driver_status
CREATE POLICY "Drivers can view own status"
  ON driver_status FOR SELECT
  USING (auth.uid() = driver_id);

CREATE POLICY "Drivers can update own status"
  ON driver_status FOR UPDATE
  USING (auth.uid() = driver_id);

-- RLS Policies for loads
CREATE POLICY "Drivers can view assigned loads"
  ON loads FOR SELECT
  USING (auth.uid() = driver_id);

CREATE POLICY "Fleet managers can view fleet loads"
  ON loads FOR SELECT
  USING (
    fleet_id IN (
      SELECT id FROM fleets WHERE manager_id = auth.uid()
    )
  );

-- RLS Policies for hos_records
CREATE POLICY "Drivers can view own HOS"
  ON hos_records FOR SELECT
  USING (auth.uid() = driver_id);

CREATE POLICY "Drivers can insert own HOS"
  ON hos_records FOR INSERT
  WITH CHECK (auth.uid() = driver_id);

-- Indexes for performance
CREATE INDEX idx_driver_status_driver_id ON driver_status(driver_id);
CREATE INDEX idx_loads_driver_id ON loads(driver_id);
CREATE INDEX idx_loads_fleet_id ON loads(fleet_id);
CREATE INDEX idx_loads_status ON loads(status);
CREATE INDEX idx_hos_records_driver_date ON hos_records(driver_id, date);
CREATE INDEX idx_vehicles_fleet_id ON vehicles(fleet_id);
CREATE INDEX idx_vehicles_driver_id ON vehicles(current_driver_id);

-- Spatial support for vehicles (optional, idempotent)
-- Enable PostGIS extension
CREATE EXTENSION IF NOT EXISTS postgis;

-- Add latitude/longitude and GEOGRAPHY location column if missing
ALTER TABLE vehicles 
  ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS location GEOGRAPHY(POINT, 4326);

-- Spatial index
CREATE INDEX IF NOT EXISTS idx_vehicles_location 
  ON vehicles USING GIST(location);

-- Function to keep location in sync with lat/lng
CREATE OR REPLACE FUNCTION update_vehicle_location()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
    NEW.location = ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326)::geography;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update location on insert/update
DROP TRIGGER IF EXISTS update_vehicles_location ON vehicles;
CREATE TRIGGER update_vehicles_location
BEFORE INSERT OR UPDATE OF latitude, longitude ON vehicles
FOR EACH ROW
EXECUTE FUNCTION update_vehicle_location();
