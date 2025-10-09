-- Truck Stops Pillar Schema for TruckerCore (Supabase / Postgres)
-- Migration file: schemas/truck_stops.sql

-- Core Truck Stop entities
CREATE TABLE IF NOT EXISTS truck_stops (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  address TEXT,
  geo_lat DOUBLE PRECISION,
  geo_lng DOUBLE PRECISION,
  operator_email TEXT,
  phone TEXT,
  tier TEXT DEFAULT 'free', -- free|ad_supported|premium
  created_at TIMESTAMP DEFAULT NOW()
);

-- Parking availability signals (crowdsourced or IoT)
CREATE TABLE IF NOT EXISTS parking_signals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  truck_stop_id UUID REFERENCES truck_stops(id),
  timestamp TIMESTAMP DEFAULT NOW(),
  reported_by TEXT, -- 'operator'|'driver'|'iot_sensor'
  available_spots INT,
  total_spots INT,
  source_confidence INT, -- e.g., 100=IOT, 70=operator, 50=driver
  premium_details JSONB
);

-- Fuel pricing published by operators
CREATE TABLE IF NOT EXISTS fuel_prices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  truck_stop_id UUID REFERENCES truck_stops(id),
  fuel_type TEXT, -- diesel|unleaded|def|other
  price_per_gallon NUMERIC,
  posted_at TIMESTAMP DEFAULT NOW(),
  valid_until TIMESTAMP
);

-- Promotions / broadcasts (geo-targeted)
CREATE TABLE IF NOT EXISTS promotions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  truck_stop_id UUID REFERENCES truck_stops(id),
  promo_type TEXT, -- discount|deal|event
  title TEXT,
  description TEXT,
  start_time TIMESTAMP,
  end_time TIMESTAMP,
  image_url TEXT,
  geo_radius INT DEFAULT 50, -- miles for geo-targeting
  is_active BOOLEAN DEFAULT TRUE
);

-- Reviews/feedback left by drivers
CREATE TABLE IF NOT EXISTS truck_stop_reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  truck_stop_id UUID REFERENCES truck_stops(id),
  left_by_driver_id UUID REFERENCES users(id),
  cleanliness INT, -- 1-5
  amenities INT,
  parking INT,
  food INT,
  overall INT,
  comment TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Digital receipts (fuel and in-store)
CREATE TABLE IF NOT EXISTS digital_receipts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  truck_stop_id UUID REFERENCES truck_stops(id),
  driver_id UUID REFERENCES users(id),
  fleet_id UUID REFERENCES fleets(id),
  amount NUMERIC,
  fuel_type TEXT,
  units_gallons NUMERIC,
  payment_token TEXT,
  transaction_time TIMESTAMP DEFAULT NOW(),
  pdf_url TEXT
);

-- Smart inventory/telemetry (tanks, showers, etc.)
CREATE TABLE IF NOT EXISTS smart_inventory (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  truck_stop_id UUID REFERENCES truck_stops(id),
  resource_type TEXT, -- "diesel_tank_1", "showers"
  percent_full INT,
  avg_wait_time INT,
  alert_active BOOLEAN DEFAULT FALSE,
  detected_time TIMESTAMP DEFAULT NOW()
);

-- Staff shifts (premium)
CREATE TABLE IF NOT EXISTS staff_shifts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  truck_stop_id UUID REFERENCES truck_stops(id),
  staff_name TEXT,
  role TEXT, -- attendant|cleaner|cashier|manager
  shift_start TIMESTAMP,
  shift_end TIMESTAMP,
  notes TEXT
);

-- Optional blockchain log (premium)
CREATE TABLE IF NOT EXISTS parking_fuel_blockchain (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ref_id UUID,
  type TEXT, -- parking|fuel
  tx_hash TEXT,
  details JSONB,
  timestamp TIMESTAMP DEFAULT NOW()
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_parking_signals_stop_time ON parking_signals(truck_stop_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_fuel_prices_stop_time ON fuel_prices(truck_stop_id, posted_at DESC);
CREATE INDEX IF NOT EXISTS idx_promotions_active ON promotions(truck_stop_id, is_active);
CREATE INDEX IF NOT EXISTS idx_reviews_stop_time ON truck_stop_reviews(truck_stop_id, created_at DESC);

-- RLS placeholders (tailor to your auth model)
-- ALTER TABLE truck_stops ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE parking_signals ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE fuel_prices ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE promotions ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE truck_stop_reviews ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE digital_receipts ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE smart_inventory ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE staff_shifts ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE parking_fuel_blockchain ENABLE ROW LEVEL SECURITY;

-- Example policy idea (customize in Supabase):
-- CREATE POLICY "operators_manage_own_stop" ON truck_stops FOR ALL
--   USING (operator_email = auth.jwt() ->> 'email') WITH CHECK (operator_email = auth.jwt() ->> 'email');
