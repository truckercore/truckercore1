-- Driver Pillar Schema for TruckerCore (Supabase/Postgres)
-- Migration file: schemas/driver_pillar.sql
-- Safe to run multiple times; uses IF NOT EXISTS. Review and tailor RLS.

-- CREATE EXTENSION IF NOT EXISTS pgcrypto; -- for gen_random_uuid()

-- DRIVERS
CREATE TABLE IF NOT EXISTS drivers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    first_name TEXT,
    last_name TEXT,
    phone TEXT,
    carrier_id UUID, -- if dispatched by a carrier
    license_number TEXT,
    cdl_expiry DATE,
    is_premium BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- SAVED VEHICLE PROFILES
CREATE TABLE IF NOT EXISTS driver_vehicles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id UUID REFERENCES drivers(id),
    vin TEXT,
    plate_number TEXT,
    specs JSONB, -- height, weight, hazmat, etc.
    created_at TIMESTAMP DEFAULT NOW()
);

-- DRIVER ROUTE HISTORY & LIVE TRIP
CREATE TABLE IF NOT EXISTS driver_trips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id UUID REFERENCES drivers(id),
    vehicle_id UUID REFERENCES driver_vehicles(id),
    load_id UUID, -- nullable if O/O or own job
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    start_coords JSONB,
    end_coords JSONB,
    route_summary JSONB, -- { distance, eta, tolls, restrictions, fuel_stops, etc. }
    route_gpx JSONB       -- geometry as geojson or encoded polyline
);

-- POI (TRUCKERCORE/COMMUNITY-EVOLVED)
CREATE TABLE IF NOT EXISTS points_of_interest (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    poi_type TEXT, -- truck_stop|rest_area|weigh_station|repair|parking
    name TEXT,
    geo_lat DOUBLE PRECISION,
    geo_lng DOUBLE PRECISION,
    description TEXT,
    amenities JSONB,
    created_by UUID REFERENCES drivers(id),
    source TEXT DEFAULT 'system', -- system|community
    created_at TIMESTAMP DEFAULT NOW()
);

-- COMMUNITY FEEDBACK/REVIEWS
CREATE TABLE IF NOT EXISTS driver_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id UUID REFERENCES drivers(id),
    poi_id UUID REFERENCES points_of_interest(id),
    cleanliness INT,
    comfort INT,
    parking INT,
    food INT,
    safety INT,
    overall INT,
    comment TEXT,
    photo_url TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- FUEL PRICES + OPTIMIZATION
CREATE TABLE IF NOT EXISTS fuel_price_spots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    poi_id UUID REFERENCES points_of_interest(id),
    fuel_type TEXT,
    price NUMERIC,
    updated_at TIMESTAMP DEFAULT NOW(),
    posted_by UUID -- user/system
);

-- LOYALTY WALLET (MULTI-BRAND)
CREATE TABLE IF NOT EXISTS loyalty_wallets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id UUID REFERENCES drivers(id),
    provider TEXT, -- loves|ta|pilot|other
    card_number TEXT,
    points_balance INT,
    updated_at TIMESTAMP DEFAULT NOW()
);

-- DIGITAL RECEIPTS (for fuel/parking/shower)
CREATE TABLE IF NOT EXISTS driver_receipts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id UUID REFERENCES drivers(id),
    expense_type TEXT, -- fuel|parking|shower|food|other
    provider TEXT,
    amount NUMERIC,
    points_earned INT,
    receipt_url TEXT,
    txn_time TIMESTAMP DEFAULT NOW()
);

-- PARKING/PREMIUM CROWD-REPORTS
CREATE TABLE IF NOT EXISTS parking_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    poi_id UUID REFERENCES points_of_interest(id),
    driver_id UUID REFERENCES drivers(id),
    report_time TIMESTAMP DEFAULT NOW(),
    available_spots INT,
    confidence INT,
    is_premium_report BOOLEAN DEFAULT FALSE
);

-- BOOKED LOADS (From Broker Marketplace)
CREATE TABLE IF NOT EXISTS booked_loads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id UUID REFERENCES drivers(id),
    load_id UUID REFERENCES loads(id),
    booking_time TIMESTAMP DEFAULT NOW(),
    status TEXT DEFAULT 'active'
);

-- AI COACHING/ROADDOGG INTERACTIONS
CREATE TABLE IF NOT EXISTS ai_personal_assistant_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id UUID REFERENCES drivers(id),
    topic TEXT, -- expense|route|hos|weather|etc.
    ai_reply TEXT,
    query_time TIMESTAMP DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_drivers_user ON drivers(user_id);
CREATE INDEX IF NOT EXISTS idx_driver_vehicles_driver ON driver_vehicles(driver_id);
CREATE INDEX IF NOT EXISTS idx_driver_trips_driver_time ON driver_trips(driver_id, start_time);
CREATE INDEX IF NOT EXISTS idx_pois_type ON points_of_interest(poi_type);
CREATE INDEX IF NOT EXISTS idx_reviews_poi_time ON driver_reviews(poi_id, created_at);
CREATE INDEX IF NOT EXISTS idx_fuel_price_spots_poi_time ON fuel_price_spots(poi_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_loyalty_wallets_driver ON loyalty_wallets(driver_id);
CREATE INDEX IF NOT EXISTS idx_driver_receipts_driver_time ON driver_receipts(driver_id, txn_time);
CREATE INDEX IF NOT EXISTS idx_parking_reports_poi_time ON parking_reports(poi_id, report_time);
CREATE INDEX IF NOT EXISTS idx_booked_loads_driver_time ON booked_loads(driver_id, booking_time);

-- RLS placeholders (uncomment and tailor in Supabase)
-- ALTER TABLE drivers ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY drivers_self ON drivers FOR SELECT USING (user_id = auth.uid());
-- Repeat for other tables, scoping by driver_id or created_by as appropriate.
