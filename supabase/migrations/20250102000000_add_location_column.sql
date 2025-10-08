-- Migration: Add spatial support for vehicles
-- Version: 20250102000000
-- Description: Add latitude/longitude, PostGIS location column and indexes

BEGIN;

CREATE EXTENSION IF NOT EXISTS postgis;

ALTER TABLE vehicles 
  ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS location GEOGRAPHY(POINT, 4326);

CREATE INDEX IF NOT EXISTS idx_vehicles_location 
  ON vehicles USING GIST(location);

CREATE OR REPLACE FUNCTION update_vehicle_location()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
    NEW.location = ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326)::geography;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_vehicles_location ON vehicles;
CREATE TRIGGER update_vehicles_location
BEFORE INSERT OR UPDATE OF latitude, longitude ON vehicles
FOR EACH ROW
EXECUTE FUNCTION update_vehicle_location();

-- Backfill any existing rows
UPDATE vehicles 
SET location = ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography
WHERE latitude IS NOT NULL AND longitude IS NOT NULL AND location IS NULL;

COMMIT;
