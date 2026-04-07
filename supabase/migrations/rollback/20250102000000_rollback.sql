-- Rollback: Remove spatial support
-- Version: 20250102000000

BEGIN;

DROP TRIGGER IF EXISTS update_vehicles_location ON vehicles;
DROP FUNCTION IF EXISTS update_vehicle_location();
DROP INDEX IF EXISTS idx_vehicles_location;
ALTER TABLE vehicles DROP COLUMN IF EXISTS location;
-- Keep latitude/longitude if other code depends on them; comment next lines to retain
-- ALTER TABLE vehicles DROP COLUMN IF EXISTS latitude;
-- ALTER TABLE vehicles DROP COLUMN IF EXISTS longitude;

COMMIT;
