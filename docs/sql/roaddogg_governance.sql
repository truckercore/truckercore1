-- roaddogg_governance.sql

CREATE TABLE IF NOT EXISTS ml_lineage (
  id bigserial PRIMARY KEY,
  org_id uuid NOT NULL,
  model_id uuid REFERENCES ml_models(id) ON DELETE CASCADE,
  training_job_id uuid REFERENCES ml_training_jobs(id) ON DELETE SET NULL,
  dataset_id uuid REFERENCES ml_datasets(id) ON DELETE SET NULL,
  feature_view_id uuid REFERENCES ml_feature_views(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE ml_lineage ENABLE ROW LEVEL SECURITY;
CREATE POLICY IF NOT EXISTS ml_lineage_ro ON ml_lineage FOR SELECT USING (rls_same_org(org_id));
CREATE POLICY IF NOT EXISTS ml_lineage_w  ON ml_lineage FOR ALL USING (is_roaddogg()) WITH CHECK (is_roaddogg());
