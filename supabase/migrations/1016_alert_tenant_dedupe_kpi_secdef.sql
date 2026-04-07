-- 1016_alert_tenant_dedupe_kpi_secdef.sql
-- Purpose: Per kind/tenant dedupe & suppression, TTM KPI views, and SECDEF manifest snapshotting.
-- Idempotent and additive across environments.

-- 1) Per-tenant overrides and org-aware outbox --------------------------------
ALTER TABLE IF EXISTS public.alert_outbox
  ADD COLUMN IF NOT EXISTS org_id uuid;

CREATE TABLE IF NOT EXISTS public.alert_route_overrides (
  key text NOT NULL,
  org_id uuid NOT NULL,
  dedupe_minutes int NOT NULL DEFAULT 15,
  enabled boolean NOT NULL DEFAULT true,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (key, org_id)
);

-- Backfill: if payload contains org_id and outbox.org_id is null, best-effort populate (optional, safe no-op if none)
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='alert_outbox' AND column_name='payload') THEN
    EXECUTE $$
      UPDATE public.alert_outbox a
      SET org_id = COALESCE(a.org_id, (a.payload->>'org_id')::uuid)
      WHERE a.org_id IS NULL AND (a.payload ? 'org_id')
    $$;
  END IF;
END $$;

-- Replace enqueue_alert with org-aware signature (compatible: p_org_id defaults to null)
CREATE OR REPLACE FUNCTION public.enqueue_alert(p_key text, p_payload jsonb, p_org_id uuid DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE
  route record;
  ov record;
  fp text;
  until_ts timestamptz;
  org uuid := p_org_id;
  minutes int;
BEGIN
  -- Prefer explicit param, else infer from payload.org_id if present
  IF org IS NULL AND (p_payload ? 'org_id') THEN
    BEGIN org := (p_payload->>'org_id')::uuid; EXCEPTION WHEN others THEN org := NULL; END;
  END IF;

  SELECT * INTO route FROM public.alert_routes WHERE key = p_key AND enabled LIMIT 1;
  IF NOT FOUND THEN
    route := (p_key, 'slack', 15, 30, true, now());
  END IF;

  -- Tenant override (if exists and enabled)
  SELECT * INTO ov FROM public.alert_route_overrides WHERE key = p_key AND org_id IS NOT NULL AND org_id = org AND enabled LIMIT 1;
  minutes := COALESCE(ov.dedupe_minutes, route.dedupe_minutes);

  -- Include org in dedupe fingerprint to avoid cross-tenant suppression
  fp := p_key || ':' || COALESCE(org::text, '*') || ':' || public.json_sha256(p_payload);
  until_ts := now() + (minutes || ' minutes')::interval;

  -- Suppress if under window
  IF EXISTS (
    SELECT 1 FROM public.alert_outbox
    WHERE dedupe_key = fp AND delivered_at IS NULL
      AND (suppress_until IS NULL OR suppress_until > now())
  ) THEN RETURN; END IF;

  INSERT INTO public.alert_outbox(key, payload, dedupe_key, suppress_until, org_id)
  VALUES (p_key, p_payload, fp, until_ts, org);
END; $$;

-- 2) KPI: Time-to-mitigate (TTM) for alerts -----------------------------------
-- Last 7 days: time from triggered to acknowledged (minutes)
CREATE OR REPLACE VIEW public.kpi_time_to_ack_7d AS
SELECT
  code,
  count(*) AS cnt,
  round(avg(extract(epoch FROM (acknowledged_at - triggered_at)) / 60.0)::numeric, 2) AS avg_minutes,
  percentile_disc(0.50) WITHIN GROUP (ORDER BY extract(epoch FROM (acknowledged_at - triggered_at)) / 60.0) AS p50_minutes,
  percentile_disc(0.95) WITHIN GROUP (ORDER BY extract(epoch FROM (acknowledged_at - triggered_at)) / 60.0) AS p95_minutes
FROM public.alerts_events
WHERE acknowledged = true
  AND acknowledged_at IS NOT NULL
  AND triggered_at >= now() - interval '7 days'
GROUP BY code
ORDER BY avg_minutes DESC NULLS LAST;

-- Quarantine/greenline specific KPI (30d)
CREATE OR REPLACE VIEW public.kpi_quarantine_ttm_30d AS
SELECT
  code,
  count(*) AS cnt,
  round(avg(extract(epoch FROM (acknowledged_at - triggered_at)) / 60.0)::numeric, 2) AS avg_minutes,
  min(triggered_at) AS first_seen,
  max(acknowledged_at) AS last_ack
FROM public.alerts_events
WHERE code IN ('feature_quarantined','table_quarantined','retention_quarantined')
  AND triggered_at >= now() - interval '30 days'
  AND acknowledged = true
GROUP BY code;

-- 3) SECURITY DEFINER manifest versioning -------------------------------------
CREATE TABLE IF NOT EXISTS public.secdef_fn_manifest_history (
  id bigserial PRIMARY KEY,
  schema text NOT NULL,
  name text NOT NULL,
  args text NOT NULL,
  def_hash text NOT NULL,
  has_search_path boolean NOT NULL,
  uses_dynamic_sql boolean NOT NULL,
  grants_public boolean NOT NULL,
  captured_at timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION public.snapshot_secdef_manifest()
RETURNS int LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE
  rec record;
  inserted int := 0;
  def text;
  h text;
  has_sp boolean;
  uses_exec boolean;
  grant_public boolean;
BEGIN
  FOR rec IN
    SELECT n.nspname AS schema, p.proname AS name, pg_get_function_identity_arguments(p.oid) AS args, p.oid AS oid
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname='public' AND p.prosecdef = true
  LOOP
    def := pg_get_functiondef(rec.oid);
    h := encode(digest(def::bytea, 'sha256'), 'hex');
    has_sp := position('SET search_path=public' in def) > 0;
    uses_exec := def ~* '\\mEXECUTE\\M';
    -- PUBLIC execute grants
    grant_public := EXISTS (
      SELECT 1 FROM information_schema.routine_privileges rp
      WHERE rp.routine_schema = rec.schema AND rp.routine_name = rec.name AND rp.grantee = 'PUBLIC' AND rp.privilege_type='EXECUTE'
    );

    INSERT INTO public.secdef_fn_manifest_history(schema, name, args, def_hash, has_search_path, uses_dynamic_sql, grants_public)
    VALUES (rec.schema, rec.name, rec.args, h, has_sp, uses_exec, grant_public);
    inserted := inserted + 1;
  END LOOP;
  RETURN inserted;
END; $$;

-- Optional: convenience view for latest per (schema,name,args)
CREATE OR REPLACE VIEW public.secdef_fn_manifest_latest AS
SELECT DISTINCT ON (schema, name, args)
  schema, name, args, def_hash, has_search_path, uses_dynamic_sql, grants_public, captured_at
FROM public.secdef_fn_manifest_history
ORDER BY schema, name, args, captured_at DESC;
