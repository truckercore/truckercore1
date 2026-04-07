-- roaddogg_spatiotemporal.sql
-- Spatiotemporal schema and predictions

CREATE TABLE IF NOT EXISTS st_zones (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL,
  code text NOT NULL,
  name text,
  centroid geography(Point, 4326),
  metadata jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE (org_id, code)
);

CREATE TABLE IF NOT EXISTS st_edges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL,
  from_zone uuid REFERENCES st_zones(id) ON DELETE CASCADE,
  to_zone uuid REFERENCES st_zones(id) ON DELETE CASCADE,
  distance_km numeric,
  typical_duration_min int,
  weight numeric,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE (org_id, from_zone, to_zone)
);

CREATE TABLE IF NOT EXISTS st_features_ts (
  id bigserial PRIMARY KEY,
  org_id uuid NOT NULL,
  zone_id uuid REFERENCES st_zones(id) ON DELETE CASCADE,
  ts timestamptz NOT NULL,
  feature jsonb NOT NULL
);

CREATE TABLE IF NOT EXISTS st_supply_demand (
  id bigserial PRIMARY KEY,
  org_id uuid NOT NULL,
  zone_id uuid REFERENCES st_zones(id) ON DELETE CASCADE,
  ts timestamptz NOT NULL,
  supply int NOT NULL,
  demand int NOT NULL,
  source text,
  UNIQUE (org_id, zone_id, ts)
);

CREATE TABLE IF NOT EXISTS st_capacity_imbalance_preds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL,
  model_id uuid REFERENCES ml_models(id) ON DELETE SET NULL,
  ts_target timestamptz NOT NULL,
  horizon_minutes int NOT NULL,
  details jsonb NOT NULL,
  created_at timestamptz DEFAULT now(),
  created_by uuid
);

-- Triggers
DROP TRIGGER IF EXISTS st_zones_u ON st_zones;
CREATE TRIGGER st_zones_u BEFORE UPDATE ON st_zones FOR EACH ROW EXECUTE FUNCTION set_updated_at();
DROP TRIGGER IF EXISTS st_edges_u ON st_edges;
CREATE TRIGGER st_edges_u BEFORE UPDATE ON st_edges FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- RLS
ALTER TABLE st_zones ENABLE ROW LEVEL SECURITY;
ALTER TABLE st_edges ENABLE ROW LEVEL SECURITY;
ALTER TABLE st_features_ts ENABLE ROW LEVEL SECURITY;
ALTER TABLE st_supply_demand ENABLE ROW LEVEL SECURITY;
ALTER TABLE st_capacity_imbalance_preds ENABLE ROW LEVEL SECURITY;

CREATE POLICY IF NOT EXISTS st_zones_ro ON st_zones FOR SELECT USING (rls_same_org(org_id));
CREATE POLICY IF NOT EXISTS st_edges_ro ON st_edges FOR SELECT USING (rls_same_org(org_id));
CREATE POLICY IF NOT EXISTS st_features_ts_ro ON st_features_ts FOR SELECT USING (rls_same_org(org_id));
CREATE POLICY IF NOT EXISTS st_supply_demand_ro ON st_supply_demand FOR SELECT USING (rls_same_org(org_id));
CREATE POLICY IF NOT EXISTS st_cap_preds_ro ON st_capacity_imbalance_preds FOR SELECT USING (rls_same_org(org_id));

-- Writes: Roaddogg only
CREATE POLICY IF NOT EXISTS st_zones_roaddogg_w ON st_zones FOR ALL USING (is_roaddogg()) WITH CHECK (is_roaddogg());
CREATE POLICY IF NOT EXISTS st_edges_roaddogg_w ON st_edges FOR ALL USING (is_roaddogg()) WITH CHECK (is_roaddogg());
CREATE POLICY IF NOT EXISTS st_features_ts_roaddogg_w ON st_features_ts FOR ALL USING (is_roaddogg()) WITH CHECK (is_roaddogg());
CREATE POLICY IF NOT EXISTS st_supply_demand_roaddogg_w ON st_supply_demand FOR ALL USING (is_roaddogg()) WITH CHECK (is_roaddogg());
CREATE POLICY IF NOT EXISTS st_cap_preds_roaddogg_w ON st_capacity_imbalance_preds FOR ALL USING (is_roaddogg()) WITH CHECK (is_roaddogg());