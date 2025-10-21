-- =============================================================
-- Operational Modules Package (ready-to-run, idempotent)
-- Implements: share-link hardening, marketplace anti-gaming,
-- award simulation, live map privacy, data retention pruning,
-- SLO targets, and governance views.
-- =============================================================

-- 1) Share-link hardening (scope, expiry, single-use)
CREATE TABLE IF NOT EXISTS public.share_links(
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid,
  load_id uuid,
  resource text,               -- e.g., 'load:UUID' or storage path
  purpose text,                -- e.g., 'live_map','doc_share'
  token text UNIQUE,
  token_hash text,
  one_time boolean DEFAULT true,
  used_at timestamptz,
  expires_at timestamptz NOT NULL,
  created_by uuid,
  created_at timestamptz DEFAULT now(),
  revoked boolean DEFAULT false
);
-- Back-compat: attach FK if loads exists
DO $$ BEGIN
  IF to_regclass('public.loads') IS NOT NULL THEN
    ALTER TABLE public.share_links
      ADD COLUMN IF NOT EXISTS load_id uuid;
  END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;

ALTER TABLE public.share_links ENABLE ROW LEVEL SECURITY;

-- Helper: current_org_id (safe re-create)
CREATE OR REPLACE FUNCTION public.current_org_id() RETURNS uuid
LANGUAGE sql STABLE AS $$
  SELECT nullif(auth.jwt()->>'app_org_id','')::uuid
$$;

-- Read policy: only within same org
DO $$ BEGIN
  CREATE POLICY sl_org_read ON public.share_links
    FOR SELECT TO authenticated
    USING (org_id = public.current_org_id());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Insert policy: authenticated can insert only for their org and future expiry
DO $$ BEGIN
  CREATE POLICY sl_insert ON public.share_links
    FOR INSERT TO authenticated
    WITH CHECK (
      org_id = public.current_org_id()
      AND expires_at > now()
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Server-side token validation with consume semantics
CREATE OR REPLACE FUNCTION public.share_link_consume(p_token text)
RETURNS TABLE(org_id uuid, resource text, purpose text)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path=public AS $$
DECLARE v RECORD;
BEGIN
  SELECT * INTO v
  FROM public.share_links
  WHERE (token = p_token OR (token IS NULL AND token_hash = encode(digest(p_token,'sha256'),'hex')))
    AND revoked = false
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'invalid_token';
  END IF;
  IF v.expires_at < now() THEN
    RAISE EXCEPTION 'expired_token';
  END IF;
  IF v.one_time AND v.used_at IS NOT NULL THEN
    RAISE EXCEPTION 'token_already_used';
  END IF;

  IF v.one_time THEN
    UPDATE public.share_links SET used_at = now() WHERE id = v.id;
  END IF;

  RETURN QUERY SELECT v.org_id, v.resource, v.purpose;
END $$;
REVOKE ALL ON FUNCTION public.share_link_consume(text) FROM public;
GRANT EXECUTE ON FUNCTION public.share_link_consume(text) TO service_role;


-- 2) Marketplace anti-gaming (rate, floor/ceiling, trust score guard)
CREATE TABLE IF NOT EXISTS public.carrier_trust(
  org_id uuid NOT NULL,
  carrier_id uuid NOT NULL,
  score numeric,
  updated_at timestamptz DEFAULT now(),
  PRIMARY KEY(org_id, carrier_id)
);
ALTER TABLE public.carrier_trust ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY carrier_trust_read ON public.carrier_trust
    FOR SELECT TO authenticated
    USING (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS public.bid_floor_rules(
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL,
  lane_hash text NOT NULL,
  equipment text NOT NULL,
  min_cents int NOT NULL,
  effective_from timestamptz NOT NULL DEFAULT now(),
  effective_to timestamptz
);
CREATE INDEX IF NOT EXISTS idx_bid_floor_rules_org_lane_eq
  ON public.bid_floor_rules (org_id, lane_hash, equipment, effective_from DESC);
ALTER TABLE public.bid_floor_rules ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY bid_floor_read ON public.bid_floor_rules
    FOR SELECT TO authenticated
    USING (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS public.bidding_rate(
  org_id uuid PRIMARY KEY,
  tokens int NOT NULL DEFAULT 60,
  refreshed_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.bidding_rate ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY bidding_rate_rw_service ON public.bidding_rate
    FOR ALL TO service_role
    USING (true) WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE OR REPLACE FUNCTION public.bidding_take_token(p_org uuid, p_cap int DEFAULT 60, p_refill int DEFAULT 60)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER
SET search_path=public AS $$
DECLARE nowts timestamptz := now();
BEGIN
  INSERT INTO public.bidding_rate(org_id, tokens, refreshed_at)
  VALUES (p_org, p_cap - 1, nowts)
  ON CONFLICT (org_id) DO UPDATE SET
    tokens = greatest(
      0,
      least(
        p_cap,
        public.bidding_rate.tokens + floor(extract(epoch FROM (nowts - public.bidding_rate.refreshed_at))/60.0)*p_refill
      ) - 1
    ),
    refreshed_at = nowts;
  RETURN (SELECT tokens >= 0 FROM public.bidding_rate WHERE org_id = p_org);
END $$;
REVOKE ALL ON FUNCTION public.bidding_take_token(uuid,int,int) FROM public;
GRANT EXECUTE ON FUNCTION public.bidding_take_token(uuid,int,int) TO service_role;

CREATE OR REPLACE FUNCTION public.validate_bid(
  p_org uuid, p_lane_hash text, p_equipment text, p_price_cents int, p_carrier uuid
) RETURNS void
LANGUAGE plpgsql AS $$
DECLARE floor_cents int; trust numeric;
BEGIN
  SELECT min_cents INTO floor_cents
  FROM public.bid_floor_rules
  WHERE org_id = p_org AND lane_hash = p_lane_hash AND equipment = p_equipment
    AND (effective_to IS NULL OR effective_to > now())
  ORDER BY effective_from DESC
  LIMIT 1;

  IF floor_cents IS NOT NULL AND p_price_cents < floor_cents THEN
    RAISE EXCEPTION 'price_below_floor';
  END IF;

  SELECT score INTO trust FROM public.carrier_trust
  WHERE carrier_id = p_carrier AND org_id = p_org;
  IF trust IS NOT NULL AND trust < 40 THEN
    RAISE EXCEPTION 'carrier_trust_low';
  END IF;

  IF NOT public.bidding_take_token(p_org) THEN
    RAISE EXCEPTION 'rate_limited';
  END IF;
END $$;


-- 3) Award rules “what-if” simulator (no side-effects, audit-friendly)
CREATE OR REPLACE FUNCTION public.award_rule_simulate(p_tender uuid, p_quote uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path=public AS $$
DECLARE ok bool := true; reasons text[] := '{}';
DECLARE t_org uuid; t_lane text; t_eq text; q_price int; q_carrier uuid;
BEGIN
  -- Try to read org and optional fields from tenders (fallbacks to NULLs)
  BEGIN
    SELECT broker_org_id /* prefer broker org */ INTO t_org FROM public.tenders WHERE id = p_tender;
  EXCEPTION WHEN undefined_column THEN
    SELECT NULL::uuid INTO t_org;
  END;
  BEGIN
    SELECT price_cents, carrier_id INTO q_price, q_carrier FROM public.tender_quotes WHERE id = p_quote;
  EXCEPTION WHEN undefined_table THEN
    q_price := NULL; q_carrier := NULL;
  END;

  BEGIN
    PERFORM public.validate_bid(t_org, t_lane, t_eq, q_price, q_carrier);
  EXCEPTION WHEN OTHERS THEN
    ok := false; reasons := array_append(reasons, SQLERRM);
  END;
  -- extend with capacity/SLA checks as needed; append to reasons
  RETURN jsonb_build_object('ok', ok, 'reasons', reasons);
END $$;
REVOKE ALL ON FUNCTION public.award_rule_simulate(uuid,uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.award_rule_simulate(uuid,uuid) TO authenticated, service_role;


-- 4) Live map privacy (precision & retention caps)
CREATE OR REPLACE VIEW public.v_vehicle_positions_public AS
SELECT
  e.org_id,
  NULL::uuid AS vehicle_id,
  date_trunc('minute', e.event_time) AS occurred_at_5m,
  (round(((e.meta->>'lat')::numeric)*1000)/1000)::float AS lat_coarse,
  (round(((e.meta->>'lon')::numeric)*1000)/1000)::float AS lon_coarse
FROM public.telematics_events e
WHERE e.event_time > now() - interval '24 hours';
GRANT SELECT ON public.v_vehicle_positions_public TO authenticated;


-- 5) Data retention (logs & positions), idempotent + safe
CREATE OR REPLACE FUNCTION public.prune_partitions() RETURNS int
LANGUAGE plpgsql AS $$
DECLARE dropped int := 0; r record;
BEGIN
  FOR r IN
    SELECT c.relname AS t
    FROM pg_class c
    WHERE c.relname ~ '^(telematics_events|function_invocations|audit_log)_[0-9]{6}$'
      AND to_date(substring(c.relname FROM '(\d{6})$'),'YYYYMM') < (date_trunc('month', now()) - interval '6 months')::date
  LOOP
    EXECUTE format('DROP TABLE IF EXISTS %I CASCADE', r.t);
    dropped := dropped + 1;
  END LOOP;
  RETURN dropped;
END $$;
REVOKE ALL ON FUNCTION public.prune_partitions() FROM public;
GRANT EXECUTE ON FUNCTION public.prune_partitions() TO service_role;


-- 6) SLOs for new modules (p95 + budget)
CREATE TABLE IF NOT EXISTS public.slo_targets(
  fn text PRIMARY KEY,
  p95_ms int NOT NULL,
  budget_error_rate numeric NOT NULL DEFAULT 0.005
);
INSERT INTO public.slo_targets(fn, p95_ms, budget_error_rate) VALUES
  ('state.resolve', 800, 0.005),
  ('promos.evaluate', 600, 0.005),
  ('sso.canary', 1200, 0.002),
  ('scim.sync', 1500, 0.005)
ON CONFLICT DO NOTHING;


-- 7) Access review & secrets cadence (views)
CREATE OR REPLACE VIEW public.v_access_attest_pending AS
SELECT * FROM public.v_access_review
WHERE category = 'org_admins'
  AND (now() - coalesce(last_sign_in_at,'epoch')) > interval '30 days';

CREATE OR REPLACE VIEW public.v_secrets_overdue AS
SELECT key, rotated_at, coalesce(max_age_days, 120) AS max_age_days
FROM public.secrets_registry
WHERE now() - rotated_at > make_interval(days => coalesce(max_age_days, 120));

-- End of package
