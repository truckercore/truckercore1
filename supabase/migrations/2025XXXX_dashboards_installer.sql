-- 2025XXXX_dashboards_installer.sql
-- Idempotent: storage RLS, COI auditing, billing price id, observability, indexes, limits, dashboards installer

-- Storage write RLS guard (bucket-specific: 'coi')
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='storage' AND tablename='objects' AND policyname='coi-writes-require-auth'
  ) THEN
    CREATE POLICY "coi-writes-require-auth" ON storage.objects
      FOR INSERT TO authenticated
      WITH CHECK (
        bucket_id = 'coi'
        AND (COALESCE((current_setting('request.jwt.claims', true)::jsonb->>'sub'),'') <> '')
        AND (COALESCE((current_setting('request.jwt.claims', true)::jsonb->>'app_org_id'),'') <> '')
      );
  END IF;
END$$;

-- Partial index for storage.objects on bucket 'coi' to help volume queries
CREATE INDEX IF NOT EXISTS idx_storage_objects_coi_bucket
  ON storage.objects (name, created_at DESC) WHERE bucket_id = 'coi';

-- Billing: persist price_id to avoid nickname drift
ALTER TABLE IF EXISTS public.billing_subscriptions
  ADD COLUMN IF NOT EXISTS price_id text;

CREATE INDEX IF NOT EXISTS idx_billing_subscriptions_price
  ON public.billing_subscriptions (price_id);

-- Webhook resiliency: Supabase-backed idempotency cache table (if not present)
CREATE TABLE IF NOT EXISTS public.api_idempotency_keys (
  key text PRIMARY KEY,
  expires_at timestamptz NOT NULL
);

-- Observability: function-specific error log
CREATE TABLE IF NOT EXISTS public.edge_function_errors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  function_name text NOT NULL,
  context jsonb NOT NULL DEFAULT '{}'::jsonb,
  error_text text NOT NULL,
  status_code int,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_edge_func_errors_fn_time
  ON public.edge_function_errors (function_name, created_at DESC);

-- COI verification auditing: created_by, verified_by + timestamps
ALTER TABLE IF EXISTS public.coi_documents
  ADD COLUMN IF NOT EXISTS created_by uuid,
  ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now(),
  ADD COLUMN IF NOT EXISTS verified_by uuid,
  ADD COLUMN IF NOT EXISTS verified_at timestamptz;

-- COI limits: per-org and per-user caps (soft caps via views; enforce in app/edge)
CREATE TABLE IF NOT EXISTS public.coi_limits (
  org_id uuid PRIMARY KEY,
  max_files_per_org int NOT NULL DEFAULT 2000,
  max_files_per_user int NOT NULL DEFAULT 200
);

-- Helper views to count current usage
CREATE OR REPLACE VIEW public.v_coi_file_counts AS
SELECT
  (o.metadata->>'org_id')::uuid AS org_id,
  (o.metadata->>'user_id')::uuid AS user_id,
  COUNT(*)::int AS file_count
FROM storage.objects o
WHERE o.bucket_id = 'coi'
GROUP BY 1,2;

-- Dashboards installer structures
CREATE TABLE IF NOT EXISTS public.dashboards_features (
  key text PRIMARY KEY,
  description text NOT NULL,
  default_enabled boolean NOT NULL DEFAULT true
);

INSERT INTO public.dashboards_features (key, description, default_enabled) VALUES
  ('safety_summary', 'Safety summary card and aggregates', true),
  ('export_alerts_csv', 'CSV export button for alerts', true),
  ('risk_corridors', 'Top risk corridors heat layer + table', true)
ON CONFLICT (key) DO UPDATE SET description = EXCLUDED.description;

CREATE TABLE IF NOT EXISTS public.dashboards_org_features (
  org_id uuid NOT NULL,
  feature_key text NOT NULL REFERENCES public.dashboards_features(key) ON DELETE CASCADE,
  enabled boolean NOT NULL,
  updated_at timestamptz DEFAULT now(),
  PRIMARY KEY (org_id, feature_key)
);

CREATE TABLE IF NOT EXISTS public.dashboards_org_settings (
  org_id uuid PRIMARY KEY,
  layout jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE public.dashboards_org_features ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dashboards_org_settings ENABLE ROW LEVEL SECURITY;

DO $rls$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='dashboards_org_features' AND policyname='org_read_features'
  ) THEN
    CREATE POLICY org_read_features ON public.dashboards_org_features
      FOR SELECT USING (
        org_id::text = COALESCE(current_setting('request.jwt.claims', true)::jsonb->>'app_org_id',
                                current_setting('request.jwt.claims', true)::jsonb->>'org_id')
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='dashboards_org_settings' AND policyname='org_read_settings'
  ) THEN
    CREATE POLICY org_read_settings ON public.dashboards_org_settings
      FOR SELECT USING (
        org_id::text = COALESCE(current_setting('request.jwt.claims', true)::jsonb->>'app_org_id',
                                current_setting('request.jwt.claims', true)::jsonb->>'org_id')
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='dashboards_org_settings' AND policyname='org_upsert_settings'
  ) THEN
    CREATE POLICY org_upsert_settings ON public.dashboards_org_settings
      FOR INSERT WITH CHECK (
        org_id::text = COALESCE(current_setting('request.jwt.claims', true)::jsonb->>'app_org_id',
                                current_setting('request.jwt.claims', true)::jsonb->>'org_id')
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='dashboards_org_settings' AND policyname='org_update_settings'
  ) THEN
    CREATE POLICY org_update_settings ON public.dashboards_org_settings
      FOR UPDATE USING (
        org_id::text = COALESCE(current_setting('request.jwt.claims', true)::jsonb->>'app_org_id',
                                current_setting('request.jwt.claims', true)::jsonb->>'org_id')
      )
      WITH CHECK (true);
  END IF;
END
$rls$;

CREATE OR REPLACE FUNCTION public.install_dashboards_for_org(p_org uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=public
AS $$
BEGIN
  INSERT INTO public.dashboards_org_features (org_id, feature_key, enabled)
  SELECT p_org, f.key, f.default_enabled
  FROM public.dashboards_features f
  ON CONFLICT (org_id, feature_key) DO UPDATE SET enabled = EXCLUDED.enabled, updated_at = now();

  INSERT INTO public.dashboards_org_settings (org_id, layout)
  VALUES (p_org, jsonb_build_object(
    'widgets', jsonb_build_array('SafetySummaryCard','ExportAlertsCSVButton','TopRiskCorridors')
  ))
  ON CONFLICT (org_id) DO NOTHING;
END $$;

REVOKE ALL ON FUNCTION public.install_dashboards_for_org(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.install_dashboards_for_org(uuid) TO service_role, authenticated;
