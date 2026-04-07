-- roaddogg_ml_core.sql
-- Core ML registry, datasets, feature views, training jobs.

-- Model family enum (distinct from any existing model kind)
DO $$ BEGIN
  CREATE TYPE ml_model_family AS ENUM ('gbm','random_forest','sarima','lstm','gnn','stgcnn','hybrid_stack');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Datasets
CREATE TABLE IF NOT EXISTS ml_datasets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL,
  name text NOT NULL,
  description text,
  source text,
  schema_json jsonb,
  rows_count bigint,
  time_range tstzrange,
  created_by uuid,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Feature views
CREATE TABLE IF NOT EXISTS ml_feature_views (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL,
  name text NOT NULL,
  sql text NOT NULL,
  ttl_minutes int DEFAULT 1440,
  created_by uuid,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE (org_id, name)
);

-- Training jobs
CREATE TABLE IF NOT EXISTS ml_training_jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL,
  model_family ml_model_family NOT NULL,
  config jsonb NOT NULL,
  dataset_id uuid REFERENCES ml_datasets(id) ON DELETE RESTRICT,
  feature_view_id uuid REFERENCES ml_feature_views(id) ON DELETE RESTRICT,
  status text NOT NULL DEFAULT 'queued',
  started_at timestamptz,
  finished_at timestamptz,
  metrics jsonb,
  error text,
  created_by uuid,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Attach update triggers
DROP TRIGGER IF EXISTS ml_datasets_u ON ml_datasets;
CREATE TRIGGER ml_datasets_u BEFORE UPDATE ON ml_datasets FOR EACH ROW EXECUTE FUNCTION set_updated_at();
DROP TRIGGER IF EXISTS ml_feature_views_u ON ml_feature_views;
CREATE TRIGGER ml_feature_views_u BEFORE UPDATE ON ml_feature_views FOR EACH ROW EXECUTE FUNCTION set_updated_at();
DROP TRIGGER IF EXISTS ml_training_jobs_u ON ml_training_jobs;
CREATE TRIGGER ml_training_jobs_u BEFORE UPDATE ON ml_training_jobs FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Extend existing ml_models table to include additional metadata if present; otherwise create
DO $$
BEGIN
  IF to_regclass('public.ml_models') IS NULL THEN
    CREATE TABLE ml_models (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      org_id uuid NOT NULL,
      name text NOT NULL,
      model_family ml_model_family NOT NULL,
      training_job_id uuid REFERENCES ml_training_jobs(id) ON DELETE SET NULL,
      version text NOT NULL,
      artifact_uri text NOT NULL,
      schema_in jsonb,
      schema_out jsonb,
      is_active boolean DEFAULT false,
      created_by uuid,
      created_at timestamptz DEFAULT now(),
      updated_at timestamptz DEFAULT now(),
      UNIQUE (org_id, name, version)
    );
  ELSE
    -- Add missing columns idempotently
    ALTER TABLE ml_models
      ADD COLUMN IF NOT EXISTS model_family ml_model_family,
      ADD COLUMN IF NOT EXISTS training_job_id uuid REFERENCES ml_training_jobs(id) ON DELETE SET NULL,
      ADD COLUMN IF NOT EXISTS version text,
      ADD COLUMN IF NOT EXISTS artifact_uri text,
      ADD COLUMN IF NOT EXISTS schema_in jsonb,
      ADD COLUMN IF NOT EXISTS schema_out jsonb,
      ADD COLUMN IF NOT EXISTS is_active boolean DEFAULT false,
      ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();
    -- Ensure uniqueness by (org_id,name,version)
    DO $$ BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname='uq_ml_models_org_name_version'
      ) THEN
        EXECUTE 'CREATE UNIQUE INDEX uq_ml_models_org_name_version ON ml_models(org_id, name, version)';
      END IF;
    END $$;
  END IF;
END $$;

-- Extend or create ml_predictions for compatibility
DO $$
BEGIN
  IF to_regclass('public.ml_predictions') IS NULL THEN
    CREATE TABLE ml_predictions (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      org_id uuid NOT NULL,
      model_id uuid REFERENCES ml_models(id) ON DELETE SET NULL,
      target text NOT NULL,
      horizon_minutes int NOT NULL,
      input_ref jsonb,
      output jsonb NOT NULL,
      requested_at timestamptz DEFAULT now(),
      created_at timestamptz DEFAULT now(),
      created_by uuid
    );
  ELSE
    ALTER TABLE ml_predictions
      ADD COLUMN IF NOT EXISTS model_id uuid REFERENCES ml_models(id) ON DELETE SET NULL,
      ADD COLUMN IF NOT EXISTS target text,
      ADD COLUMN IF NOT EXISTS horizon_minutes int,
      ADD COLUMN IF NOT EXISTS input_ref jsonb,
      ADD COLUMN IF NOT EXISTS output jsonb,
      ADD COLUMN IF NOT EXISTS requested_at timestamptz,
      ADD COLUMN IF NOT EXISTS created_by uuid;
  END IF;
END $$;

-- RLS enable
ALTER TABLE ml_datasets       ENABLE ROW LEVEL SECURITY;
ALTER TABLE ml_feature_views  ENABLE ROW LEVEL SECURITY;
ALTER TABLE ml_training_jobs  ENABLE ROW LEVEL SECURITY;
ALTER TABLE ml_models         ENABLE ROW LEVEL SECURITY;
ALTER TABLE ml_predictions    ENABLE ROW LEVEL SECURITY;

-- READ: same org
CREATE POLICY IF NOT EXISTS ml_datasets_ro      ON ml_datasets      FOR SELECT USING (rls_same_org(org_id));
CREATE POLICY IF NOT EXISTS ml_feature_views_ro ON ml_feature_views FOR SELECT USING (rls_same_org(org_id));
CREATE POLICY IF NOT EXISTS ml_training_jobs_ro ON ml_training_jobs FOR SELECT USING (rls_same_org(org_id));
CREATE POLICY IF NOT EXISTS ml_models_ro        ON ml_models        FOR SELECT USING (rls_same_org(org_id));
CREATE POLICY IF NOT EXISTS ml_predictions_ro   ON ml_predictions   FOR SELECT USING (rls_same_org(org_id));

-- WRITE: Roaddogg only
CREATE POLICY IF NOT EXISTS ml_datasets_roaddogg_write      ON ml_datasets      FOR ALL USING (is_roaddogg()) WITH CHECK (is_roaddogg());
CREATE POLICY IF NOT EXISTS ml_feature_views_roaddogg_write ON ml_feature_views FOR ALL USING (is_roaddogg()) WITH CHECK (is_roaddogg());
CREATE POLICY IF NOT EXISTS ml_training_jobs_roaddogg_write ON ml_training_jobs FOR ALL USING (is_roaddogg()) WITH CHECK (is_roaddogg());
CREATE POLICY IF NOT EXISTS ml_models_roaddogg_write        ON ml_models        FOR ALL USING (is_roaddogg()) WITH CHECK (is_roaddogg());
CREATE POLICY IF NOT EXISTS ml_predictions_roaddogg_write   ON ml_predictions   FOR ALL USING (is_roaddogg()) WITH CHECK (is_roaddogg());

-- Optional admin toggle for model activation
CREATE POLICY IF NOT EXISTS ml_models_admin_toggle ON ml_models
  FOR UPDATE USING (rls_same_org(org_id) AND app_role() IN ('admin','fleet_admin'))
  WITH CHECK (rls_same_org(org_id) AND app_role() IN ('admin','fleet_admin'));
