-- roaddogg_ensembles.sql

CREATE TABLE IF NOT EXISTS ml_ensembles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL,
  name text NOT NULL,
  description text,
  meta_model_id uuid REFERENCES ml_models(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE (org_id, name)
);

CREATE TABLE IF NOT EXISTS ml_ensemble_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ensemble_id uuid REFERENCES ml_ensembles(id) ON DELETE CASCADE,
  model_id uuid REFERENCES ml_models(id) ON DELETE CASCADE,
  weight numeric DEFAULT 1.0,
  order_index int DEFAULT 0,
  UNIQUE (ensemble_id, model_id)
);

ALTER TABLE ml_ensembles ENABLE ROW LEVEL SECURITY;
ALTER TABLE ml_ensemble_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY IF NOT EXISTS ml_ensembles_ro ON ml_ensembles FOR SELECT USING (rls_same_org(org_id));
CREATE POLICY IF NOT EXISTS ml_members_ro   ON ml_ensemble_members FOR SELECT USING (
  rls_same_org((SELECT org_id FROM ml_ensembles e WHERE e.id = ensemble_id))
);

-- Writes: Roaddogg only
CREATE POLICY IF NOT EXISTS ml_ensembles_w ON ml_ensembles        FOR ALL USING (is_roaddogg()) WITH CHECK (is_roaddogg());
CREATE POLICY IF NOT EXISTS ml_members_w   ON ml_ensemble_members FOR ALL USING (is_roaddogg()) WITH CHECK (is_roaddogg());
