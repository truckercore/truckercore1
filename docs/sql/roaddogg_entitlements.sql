-- roaddogg_entitlements.sql (optional)

CREATE TABLE IF NOT EXISTS ent_feature_flags (
  org_id uuid NOT NULL,
  feature_key text NOT NULL,
  enabled boolean NOT NULL DEFAULT false,
  updated_at timestamptz DEFAULT now(),
  PRIMARY KEY (org_id, feature_key)
);
ALTER TABLE ent_feature_flags ENABLE ROW LEVEL SECURITY;
CREATE POLICY IF NOT EXISTS ent_ro ON ent_feature_flags FOR SELECT USING (rls_same_org(org_id));
CREATE POLICY IF NOT EXISTS ent_admin_w ON ent_feature_flags
  FOR ALL USING (rls_same_org(org_id) AND app_role() IN ('admin','fleet_admin'))
  WITH CHECK (rls_same_org(org_id) AND app_role() IN ('admin','fleet_admin'));
