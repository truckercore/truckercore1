-- live_map_view.sql
-- Open “Live Map” (no login): read-only token flow

CREATE OR REPLACE VIEW v_live_map_public AS
SELECT r.load_id, re.ts, re.event,
       (re.meta->>'lat')::float AS lat,
       (re.meta->>'lon')::float AS lon,
       re.meta - 'driver_name' - 'vehicle_plate' AS meta
FROM routes r
JOIN route_events re ON re.route_id = r.id;

REVOKE ALL ON v_live_map_public FROM anon, authenticated;
