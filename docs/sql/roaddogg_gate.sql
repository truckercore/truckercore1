-- roaddogg_gate.sql
-- API keys and secure RPCs for Roaddogg service

CREATE TABLE IF NOT EXISTS roaddogg_api_keys (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL,
  label text,
  hashed_key text NOT NULL,
  scopes text[] NOT NULL DEFAULT '{predict,train,ingest}',
  last_used_at timestamptz,
  created_at timestamptz DEFAULT now(),
  UNIQUE (org_id, hashed_key)
);

ALTER TABLE roaddogg_api_keys ENABLE ROW LEVEL SECURITY;
CREATE POLICY IF NOT EXISTS roaddogg_keys_ro ON roaddogg_api_keys FOR SELECT USING (rls_same_org(org_id));
CREATE POLICY IF NOT EXISTS roaddogg_keys_admin_w ON roaddogg_api_keys
  FOR ALL USING (rls_same_org(org_id) AND app_role() IN ('admin','fleet_admin'))
  WITH CHECK (rls_same_org(org_id) AND app_role() IN ('admin','fleet_admin'));

-- Secure RPCs
CREATE OR REPLACE FUNCTION roaddogg_record_capacity_pred(
  p_org uuid,
  p_model uuid,
  p_ts_target timestamptz,
  p_horizon int,
  p_details jsonb
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=public
AS $$
DECLARE new_id uuid;
BEGIN
  IF NOT is_roaddogg() THEN
    RAISE EXCEPTION 'forbidden' USING errcode = '42501';
  END IF;
  INSERT INTO st_capacity_imbalance_preds(org_id, model_id, ts_target, horizon_minutes, details, created_by)
  VALUES (p_org, p_model, p_ts_target, p_horizon, p_details, auth.uid())
  RETURNING id INTO new_id;

  -- Mirror into ml_predictions for downstream analytics compat
  INSERT INTO ml_predictions(org_id, model_id, target, horizon_minutes, input_ref, output, created_by, requested_at)
  VALUES (p_org, p_model, 'capacity_imbalance', p_horizon, jsonb_build_object('ts_target', p_ts_target), p_details, auth.uid(), now());

  RETURN new_id;
END $$;

CREATE OR REPLACE FUNCTION roaddogg_queue_training(
  p_org uuid,
  p_model_family ml_model_family,
  p_dataset uuid,
  p_feature_view uuid,
  p_config jsonb
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=public
AS $$
DECLARE jid uuid;
BEGIN
  IF NOT is_roaddogg() THEN RAISE EXCEPTION 'forbidden' USING errcode='42501'; END IF;
  INSERT INTO ml_training_jobs(org_id, model_family, config, dataset_id, feature_view_id, status, created_by)
  VALUES (p_org, p_model_family, p_config, p_dataset, p_feature_view, 'queued', auth.uid())
  RETURNING id INTO jid;
  RETURN jid;
END $$;

REVOKE ALL ON FUNCTION roaddogg_record_capacity_pred(uuid,uuid,timestamptz,int,jsonb) FROM public;
REVOKE ALL ON FUNCTION roaddogg_queue_training(uuid,ml_model_family,uuid,uuid,jsonb) FROM public;
GRANT EXECUTE ON FUNCTION roaddogg_record_capacity_pred(uuid,uuid,timestamptz,int,jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION roaddogg_queue_training(uuid,ml_model_family,uuid,uuid,jsonb) TO service_role;
