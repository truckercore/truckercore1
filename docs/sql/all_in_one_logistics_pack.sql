-- =============================================================
-- All-in-One Logistics Pack (Safe to re-run)
-- Helpers, Broker/Marketplace, Fleet/Live Map, Financials,
-- Integrations, stricter writes, common indexes, seeds, RLS check
-- =============================================================

-- Extensions required (idempotent)
DO $$ BEGIN
  CREATE EXTENSION IF NOT EXISTS pgcrypto;
  CREATE EXTENSION IF NOT EXISTS postgis;
EXCEPTION WHEN OTHERS THEN NULL; END $$;

-- ========== COMMON HELPERS ==========
DO $$ BEGIN
  CREATE TYPE load_status AS ENUM ('draft','posted','bidding','awarded','in_transit','delivered','cancelled');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE OR REPLACE FUNCTION current_org() RETURNS uuid
LANGUAGE sql STABLE AS $$
  SELECT nullif(auth.jwt()->>'app_org_id','')::uuid
$$;

CREATE OR REPLACE FUNCTION current_role() RETURNS text
LANGUAGE sql STABLE AS $$
  SELECT coalesce(auth.jwt()->>'app_role','')
$$;

CREATE OR REPLACE FUNCTION now_utc() RETURNS timestamptz
LANGUAGE sql STABLE AS $$
  SELECT timezone('UTC', now())
$$;

-- ========== CORE ENTITIES (BROKER & MARKETPLACE) ==========
CREATE TABLE IF NOT EXISTS public.carriers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL,
  mc_number text,
  dot_number text,
  trust_score int NOT NULL DEFAULT 600, -- 300..900
  created_at timestamptz NOT NULL DEFAULT now_utc()
);

CREATE TABLE IF NOT EXISTS public.loads (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL,
  status load_status NOT NULL DEFAULT 'draft',
  pickup_at timestamptz,
  dropoff_at timestamptz,
  pickup_geom geography(point),
  dropoff_geom geography(point),
  equipment text,
  weight_kg int,
  commodity text,
  distance_km numeric,
  fuel_index_bp int DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now_utc(),
  posted_at timestamptz
);

CREATE INDEX IF NOT EXISTS loads_org_status_idx ON public.loads(org_id, status);
-- GiST for PostGIS geography
DO $$ BEGIN
  PERFORM 1 FROM pg_indexes WHERE schemaname='public' AND indexname='loads_pickup_idx';
  IF NOT FOUND THEN EXECUTE 'CREATE INDEX loads_pickup_idx ON public.loads USING gist (pickup_geom)'; END IF;
END $$;
DO $$ BEGIN
  PERFORM 1 FROM pg_indexes WHERE schemaname='public' AND indexname='loads_dropoff_idx';
  IF NOT FOUND THEN EXECUTE 'CREATE INDEX loads_dropoff_idx ON public.loads USING gist (dropoff_geom)'; END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.bids (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL,  -- broker/shipper org that owns the load
  carrier_id uuid NOT NULL REFERENCES public.carriers(id) ON DELETE CASCADE,
  load_id uuid NOT NULL REFERENCES public.loads(id) ON DELETE CASCADE,
  price_cents bigint NOT NULL,
  eta_hours numeric,
  status text NOT NULL DEFAULT 'proposed', -- proposed|accepted|rejected|expired
  created_at timestamptz NOT NULL DEFAULT now_utc(),
  UNIQUE (carrier_id, load_id)
);

CREATE INDEX IF NOT EXISTS bids_org_load_idx ON public.bids(org_id, load_id);

CREATE TABLE IF NOT EXISTS public.award_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL,
  name text NOT NULL,
  min_trust int DEFAULT 650,
  max_eta_hours numeric,
  prefer_lowest_price boolean DEFAULT true,
  weight_price numeric DEFAULT 0.7, -- 0..1
  weight_trust numeric DEFAULT 0.3,
  created_at timestamptz DEFAULT now_utc()
);

CREATE TABLE IF NOT EXISTS public.carrier_capacity (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL,
  carrier_id uuid NOT NULL REFERENCES public.carriers(id) ON DELETE CASCADE,
  available_from timestamptz NOT NULL,
  available_to timestamptz,
  home_geom geography(point),
  hours_available numeric,
  updated_at timestamptz DEFAULT now_utc()
);

-- RLS
ALTER TABLE public.carriers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bids ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.award_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.carrier_capacity ENABLE ROW LEVEL SECURITY;

CREATE POLICY carriers_org_iso ON public.carriers USING (org_id = current_org());
CREATE POLICY loads_org_iso ON public.loads USING (org_id = current_org());
CREATE POLICY bids_org_iso ON public.bids USING (org_id = current_org());
CREATE POLICY award_rules_org_iso ON public.award_rules USING (org_id = current_org());
CREATE POLICY capacity_org_iso ON public.carrier_capacity USING (org_id = current_org());

-- ========== RPCs: QUOTE / AWARD / MATCHMAKING ==========
CREATE OR REPLACE FUNCTION public.get_quote(p_load_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=public
AS $$
DECLARE
  v_load public.loads%rowtype;
  base_rate_cpm numeric := 2.25;
  fuel_adj_bp int;
  distance_mi numeric;
  trust_avg numeric;
  price_cents bigint;
BEGIN
  SELECT * INTO v_load FROM public.loads
   WHERE id = p_load_id AND org_id = current_org() FOR SHARE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'load not found' USING errcode = 'P0002';
  END IF;

  distance_mi := coalesce(v_load.distance_km,0) * 0.621371;
  fuel_adj_bp := coalesce(v_load.fuel_index_bp,0);
  SELECT avg(trust_score) INTO trust_avg FROM public.carriers WHERE org_id = current_org();

  price_cents := ceil(
    100 * distance_mi *
    (base_rate_cpm * (1 + fuel_adj_bp/10000.0)) *
    CASE WHEN coalesce(trust_avg,650) > 700 THEN 0.98 ELSE 1.0 END
  );

  RETURN jsonb_build_object(
    'load_id', p_load_id,
    'distance_mi', distance_mi,
    'price_cents', price_cents,
    'fuel_adj_bp', fuel_adj_bp
  );
END $$;

CREATE OR REPLACE FUNCTION public.apply_award_rules(p_load_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=public
AS $$
DECLARE
  v_bid public.bids%rowtype;
BEGIN
  WITH cfg AS (
    SELECT *
    FROM public.award_rules
    WHERE org_id = current_org()
    ORDER BY created_at DESC
    LIMIT 1
  ),
  eligible AS (
    SELECT b.*, c.trust_score,
      (coalesce((SELECT weight_price FROM cfg),0.7) * (1.0 / greatest(b.price_cents,1)) +
       coalesce((SELECT weight_trust FROM cfg),0.3) * (coalesce(c.trust_score,600) / 1000.0)) AS score
    FROM public.bids b
    JOIN public.carriers c ON c.id = b.carrier_id
    WHERE b.org_id = current_org()
      AND b.load_id = p_load_id
      AND b.status = 'proposed'
      AND (coalesce((SELECT min_trust FROM cfg), NULL) IS NULL OR c.trust_score >= (SELECT min_trust FROM cfg))
      AND (coalesce((SELECT max_eta_hours FROM cfg), NULL) IS NULL OR b.eta_hours <= (SELECT max_eta_hours FROM cfg))
  )
  SELECT * INTO v_bid FROM eligible ORDER BY score DESC LIMIT 1;

  IF NOT FOUND THEN RAISE EXCEPTION 'no eligible bids'; END IF;

  UPDATE public.bids SET status='accepted'
   WHERE id = v_bid.id AND org_id = current_org();

  UPDATE public.bids SET status='rejected'
   WHERE org_id = current_org() AND load_id = p_load_id AND id <> v_bid.id AND status='proposed';

  UPDATE public.loads SET status='awarded' WHERE id = p_load_id AND org_id = current_org();

  RETURN v_bid.id;
END $$;

CREATE OR REPLACE FUNCTION public.find_best_carrier(p_load_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=public
AS $$
DECLARE v public.loads%rowtype; cid uuid;
BEGIN
  SELECT * INTO v FROM public.loads WHERE id=p_load_id AND org_id=current_org();
  IF NOT FOUND THEN RAISE EXCEPTION 'load not found'; END IF;

  WITH ranked AS (
    SELECT cc.carrier_id,
           c.trust_score,
           (coalesce(c.trust_score,600)/1000.0 + coalesce(cc.hours_available,0)/100.0) AS score
    FROM public.carrier_capacity cc
    JOIN public.carriers c ON c.id = cc.carrier_id
    WHERE cc.org_id = current_org()
      AND (cc.available_to IS NULL OR cc.available_to > now_utc())
  )
  SELECT carrier_id INTO cid FROM ranked ORDER BY score DESC LIMIT 1;

  RETURN cid;
END $$;

-- ========== FLEET / LIVE MAP ==========
CREATE TABLE IF NOT EXISTS public.trucks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL,
  carrier_id uuid REFERENCES public.carriers(id) ON DELETE SET NULL,
  current_geom geography(point),
  current_speed_kph numeric,
  updated_at timestamptz DEFAULT now_utc()
);

CREATE TABLE IF NOT EXISTS public.routes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL,
  truck_id uuid NOT NULL REFERENCES public.trucks(id) ON DELETE CASCADE,
  dest_geom geography(point),
  path geography(linestring),
  distance_km numeric,
  optimized_at timestamptz
);

CREATE TABLE IF NOT EXISTS public.geofences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL,
  name text,
  area geography(polygon),
  created_at timestamptz DEFAULT now_utc()
);

CREATE TABLE IF NOT EXISTS public.deliveries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL,
  load_id uuid REFERENCES public.loads(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'pending', -- pending|arrived|departed|delivered
  updated_at timestamptz DEFAULT now_utc()
);

CREATE TABLE IF NOT EXISTS public.hos_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL,
  truck_id uuid NOT NULL REFERENCES public.trucks(id) ON DELETE CASCADE,
  driving_minutes int NOT NULL DEFAULT 0,
  rest_minutes int NOT NULL DEFAULT 0,
  day date NOT NULL
);

-- RLS
ALTER TABLE public.trucks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.routes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.geofences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.deliveries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hos_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY trucks_org_iso ON public.trucks USING (org_id=current_org());
CREATE POLICY routes_org_iso ON public.routes USING (org_id=current_org());
CREATE POLICY geofences_org_iso ON public.geofences USING (org_id=current_org());
CREATE POLICY deliveries_org_iso ON public.deliveries USING (org_id=current_org());
CREATE POLICY hos_logs_org_iso ON public.hos_logs USING (org_id=current_org());

-- RPCs
CREATE OR REPLACE FUNCTION public.optimize_route(p_truck_id uuid, p_dest geography)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=public
AS $$
DECLARE r_id uuid; g geography(point); dist_km numeric;
BEGIN
  SELECT current_geom INTO g FROM public.trucks WHERE id=p_truck_id AND org_id=current_org();
  IF g IS NULL THEN RAISE EXCEPTION 'truck not found or no position'; END IF;

  dist_km := st_distance(g::geography, p_dest::geography)/1000.0;

  INSERT INTO public.routes(org_id, truck_id, dest_geom, path, distance_km, optimized_at)
  VALUES (current_org(), p_truck_id, p_dest,
          st_makeline(st_setsrid(g::geometry,4326), st_setsrid(p_dest::geometry,4326))::geography,
          dist_km, now_utc())
  RETURNING id INTO r_id;

  RETURN r_id;
END $$;

CREATE OR REPLACE FUNCTION public.handle_geofence_event(p_truck_id uuid, p_event text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=public
AS $$
DECLARE d public.deliveries%rowtype;
BEGIN
  SELECT d.* INTO d FROM public.deliveries d
  JOIN public.loads l ON l.id = d.load_id
  WHERE d.org_id=current_org() AND l.status IN ('in_transit','awarded')
  ORDER BY d.updated_at DESC LIMIT 1;

  IF NOT FOUND THEN RETURN; END IF;

  IF p_event = 'enter' THEN
    UPDATE public.deliveries SET status='arrived', updated_at=now_utc() WHERE id=d.id AND org_id=current_org();
  ELSIF p_event = 'exit' THEN
    UPDATE public.deliveries SET status='departed', updated_at=now_utc() WHERE id=d.id AND org_id=current_org();
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.calculate_eta(p_truck_id uuid, p_dest geography)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=public
AS $$
DECLARE g geography(point); dist_km numeric; speed_kph numeric; eta_hours numeric;
BEGIN
  SELECT current_geom, coalesce(current_speed_kph, 80) INTO g, speed_kph
  FROM public.trucks WHERE id=p_truck_id AND org_id=current_org();

  IF g IS NULL THEN RAISE EXCEPTION 'truck not found'; END IF;

  dist_km := st_distance(g::geography, p_dest::geography)/1000.0;
  eta_hours := CASE WHEN speed_kph > 0 THEN dist_km / speed_kph ELSE NULL END;

  PERFORM 1 FROM public.hos_logs WHERE truck_id=p_truck_id AND org_id=current_org() AND day=current_date AND rest_minutes < 600;
  IF FOUND AND eta_hours IS NOT NULL THEN
    eta_hours := eta_hours * 1.15;
  END IF;

  RETURN jsonb_build_object('distance_km', dist_km, 'eta_hours', eta_hours);
END $$;

-- ========== FINANCIALS ==========
DO $$ BEGIN
  CREATE TYPE invoice_status AS ENUM ('draft','open','due','paid','void');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS public.invoices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL,
  number text,
  period_start date,
  period_end date,
  subtotal_cents bigint NOT NULL DEFAULT 0,
  tax_cents bigint NOT NULL DEFAULT 0,
  total_cents bigint NOT NULL DEFAULT 0,
  status invoice_status NOT NULL DEFAULT 'draft',
  idempotency_key text,
  created_at timestamptz DEFAULT now_utc(),
  UNIQUE (org_id, idempotency_key)
);

CREATE TABLE IF NOT EXISTS public.invoice_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL,
  invoice_id uuid NOT NULL REFERENCES public.invoices(id) ON DELETE CASCADE,
  description text,
  qty int NOT NULL DEFAULT 1,
  unit_price_cents bigint NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS public.payrolls (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL,
  driver_id uuid,
  period_start date, period_end date,
  gross_cents bigint NOT NULL DEFAULT 0,
  advance_cents bigint NOT NULL DEFAULT 0,
  net_cents bigint NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now_utc()
);

CREATE TABLE IF NOT EXISTS public.expenses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL,
  driver_id uuid,
  truck_id uuid,
  trip_id uuid,
  category text,
  amount_cents bigint NOT NULL,
  occurred_at timestamptz NOT NULL,
  source text,
  status text DEFAULT 'unreconciled'
);

CREATE TABLE IF NOT EXISTS public.fuel_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL,
  card_last4 text,
  driver_id uuid,
  truck_id uuid,
  gallons numeric,
  price_cents bigint,
  station_id text,
  occurred_at timestamptz NOT NULL,
  matched_expense_id uuid REFERENCES public.expenses(id) ON DELETE SET NULL
);

-- RLS
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoice_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payrolls ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fuel_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY inv_org_iso ON public.invoices USING (org_id=current_org());
CREATE POLICY inv_items_org_iso ON public.invoice_items USING (org_id=current_org());
CREATE POLICY payroll_org_iso ON public.payrolls USING (org_id=current_org());
CREATE POLICY expenses_org_iso ON public.expenses USING (org_id=current_org());
CREATE POLICY fuel_tx_org_iso ON public.fuel_transactions USING (org_id=current_org());

-- RPCs
CREATE OR REPLACE FUNCTION public.generate_invoices(p_start date, p_end date, p_idem text DEFAULT NULL)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=public
AS $$
DECLARE inv_id uuid; cnt int:=0; total bigint;
BEGIN
  IF p_idem IS NOT NULL THEN
    SELECT id INTO inv_id FROM public.invoices WHERE org_id=current_org() AND idempotency_key=p_idem;
  END IF;

  IF inv_id IS NULL THEN
    INSERT INTO public.invoices(org_id, number, period_start, period_end, status, idempotency_key)
    VALUES (current_org(), concat('INV-', to_char(now_utc(),'YYYYMMDDHH24MISS')), p_start, p_end, 'open', p_idem)
    RETURNING id INTO inv_id;
  END IF;

  INSERT INTO public.invoice_items(org_id, invoice_id, description, qty, unit_price_cents)
  SELECT current_org(), inv_id, concat('Load ', l.id::text), 1, coalesce(b.price_cents, 0)
  FROM public.loads l
  LEFT JOIN public.bids b ON b.load_id = l.id AND b.status='accepted' AND b.org_id=current_org()
  WHERE l.org_id=current_org() AND l.status='delivered'
    AND l.dropoff_at::date BETWEEN p_start AND p_end;

  SELECT coalesce(sum(qty*unit_price_cents),0) INTO total FROM public.invoice_items WHERE invoice_id=inv_id AND org_id=current_org();
  UPDATE public.invoices SET subtotal_cents=total, tax_cents=0, total_cents=total WHERE id=inv_id AND org_id=current_org();

  GET DIAGNOSTICS cnt = ROW_COUNT;
  RETURN cnt;
END $$;

CREATE OR REPLACE FUNCTION public.close_billing_period(p_start date, p_end date)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=public
AS $$
DECLARE ar bigint; ap bigint; pl bigint;
BEGIN
  UPDATE public.invoices SET status='due'
   WHERE org_id=current_org() AND period_start=p_start AND period_end=p_end AND status='open';

  SELECT coalesce(sum(total_cents),0) INTO ar FROM public.invoices WHERE org_id=current_org() AND period_start=p_start AND period_end=p_end;
  SELECT coalesce(sum(amount_cents),0) INTO ap FROM public.expenses WHERE org_id=current_org() AND occurred_at::date BETWEEN p_start AND p_end;

  pl := ar - ap;
  RETURN jsonb_build_object('period_start',p_start,'period_end',p_end,'ar_cents',ar,'ap_cents',ap,'pl_cents',pl);
END $$;

CREATE OR REPLACE FUNCTION public.reconcile_expenses(p_batch jsonb)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=public
AS $$
DECLARE matched int:=0;
BEGIN
  UPDATE public.expenses e
    SET status='matched',
        truck_id = coalesce(e.truck_id, ft.truck_id),
        driver_id = coalesce(e.driver_id, ft.driver_id)
  FROM public.fuel_transactions ft
  WHERE e.org_id=current_org() AND ft.org_id=current_org()
    AND e.category='fuel' AND e.status<>'matched'
    AND abs(extract(epoch FROM (e.occurred_at - ft.occurred_at))) < 3600*6
    AND e.amount_cents BETWEEN ft.price_cents - 1000 AND ft.price_cents + 1000;

  GET DIAGNOSTICS matched = ROW_COUNT;
  RETURN matched;
END $$;

-- ========== INTEGRATIONS ==========
CREATE TABLE IF NOT EXISTS public.integration_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL,
  provider text NOT NULL,
  token text NOT NULL,
  created_at timestamptz DEFAULT now_utc()
);

CREATE TABLE IF NOT EXISTS public.inbound_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL,
  source text NOT NULL,
  event_type text NOT NULL,
  payload jsonb NOT NULL,
  received_at timestamptz DEFAULT now_utc(),
  processed_at timestamptz
);

ALTER TABLE public.integration_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inbound_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY integ_org_iso ON public.integration_tokens USING (org_id=current_org());
CREATE POLICY inbound_org_iso ON public.inbound_events USING (org_id=current_org());

-- RPCs
CREATE OR REPLACE FUNCTION public.update_load_status(p_load_id uuid, p_new load_status)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=public
AS $$
BEGIN
  UPDATE public.loads SET status=p_new WHERE id=p_load_id AND org_id=current_org();
  IF NOT FOUND THEN RAISE EXCEPTION 'load not found or unauthorized'; END IF;
END $$;

CREATE OR REPLACE FUNCTION public.create_load_from_order(p_order jsonb)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=public
AS $$
DECLARE id uuid;
BEGIN
  INSERT INTO public.loads(org_id, status, pickup_at, dropoff_at, equipment, weight_kg, commodity, distance_km)
  VALUES (
    current_org(),
    'posted',
    (p_order->>'pickup_at')::timestamptz,
    (p_order->>'dropoff_at')::timestamptz,
    p_order->>'equipment',
    coalesce((p_order->>'weight_kg')::int, NULL),
    p_order->>'commodity',
    coalesce((p_order->>'distance_km')::numeric, NULL)
  )
  RETURNING id INTO id;

  INSERT INTO public.inbound_events(org_id, source, event_type, payload)
  VALUES (current_org(), coalesce(p_order->>'source','customer'), 'order_created', p_order);

  RETURN id;
END $$;

-- ========== OPTIONAL STRICTER WRITE CONTROLS ==========
CREATE POLICY loads_writer ON public.loads
  FOR INSERT WITH CHECK (current_role() IN ('broker','shipper','fleet_admin') AND org_id=current_org());

CREATE POLICY bids_writer ON public.bids
  FOR INSERT WITH CHECK (org_id=current_org());

CREATE POLICY inv_writer ON public.invoices
  FOR UPDATE USING (org_id=current_org()) WITH CHECK (org_id=current_org());

-- ========== COMMONLY USEFUL INDEXES ==========
CREATE INDEX IF NOT EXISTS expenses_org_time_idx ON public.expenses(org_id, occurred_at);
CREATE INDEX IF NOT EXISTS fuel_tx_org_time_idx ON public.fuel_transactions(org_id, occurred_at);
CREATE INDEX IF NOT EXISTS inbound_events_org_time ON public.inbound_events(org_id, received_at);
CREATE INDEX IF NOT EXISTS deliveries_org_status_idx ON public.deliveries(org_id, status);

-- ========== CI: UNIT SEED FIXTURES ==========
-- Minimal seed: one org, one carrier, one load, capacity, a bid
WITH s AS (
  SELECT gen_random_uuid() AS org
)
INSERT INTO public.carriers (id, org_id, mc_number, dot_number, trust_score)
SELECT gen_random_uuid(), s.org, 'MC123456', 'DOT1234567', 720 FROM s
ON CONFLICT DO NOTHING;

WITH s AS (SELECT (SELECT org_id FROM public.carriers LIMIT 1) AS org, (SELECT id FROM public.carriers LIMIT 1) AS carrier)
INSERT INTO public.loads (id, org_id, status, pickup_at, dropoff_at, equipment, distance_km, fuel_index_bp)
SELECT gen_random_uuid(), s.org, 'posted', now_utc()+ interval '1 day', now_utc()+ interval '3 days', '53'' dry van', 1500, 120 FROM s
ON CONFLICT DO NOTHING;

WITH s AS (
  SELECT
    (SELECT org_id FROM public.carriers LIMIT 1) AS org,
    (SELECT id FROM public.carriers LIMIT 1) AS carrier,
    (SELECT id FROM public.loads LIMIT 1) AS load_id
)
INSERT INTO public.carrier_capacity (org_id, carrier_id, available_from, home_geom, hours_available)
SELECT s.org, s.carrier, now_utc(), st_setsrid(st_makepoint(-74.0, 40.72),4326)::geography, 8
FROM s
ON CONFLICT DO NOTHING;

WITH s AS (
  SELECT
    (SELECT org_id FROM public.carriers LIMIT 1) AS org,
    (SELECT id FROM public.carriers LIMIT 1) AS carrier,
    (SELECT id FROM public.loads LIMIT 1) AS load_id
)
INSERT INTO public.bids (org_id, carrier_id, load_id, price_cents, eta_hours, status)
SELECT s.org, s.carrier, s.load_id, 250000, 24, 'proposed' FROM s
ON CONFLICT DO NOTHING;

-- ========== CI: RLS SIMULATOR ==========
-- View to simulate current_org() scoping quickly in CI (read-only)
CREATE OR REPLACE VIEW public.v_rls_check AS
SELECT
  'carriers' AS table, count(*) FILTER (WHERE org_id = current_org()) AS visible_rows
FROM public.carriers
UNION ALL
SELECT 'loads', count(*) FILTER (WHERE org_id = current_org()) FROM public.loads
UNION ALL
SELECT 'bids', count(*) FILTER (WHERE org_id = current_org()) FROM public.bids
UNION ALL
SELECT 'award_rules', count(*) FILTER (WHERE org_id = current_org()) FROM public.award_rules
UNION ALL
SELECT 'carrier_capacity', count(*) FILTER (WHERE org_id = current_org()) FROM public.carrier_capacity
UNION ALL
SELECT 'trucks', count(*) FILTER (WHERE org_id = current_org()) FROM public.trucks
UNION ALL
SELECT 'routes', count(*) FILTER (WHERE org_id = current_org()) FROM public.routes
UNION ALL
SELECT 'geofences', count(*) FILTER (WHERE org_id = current_org()) FROM public.geofences
UNION ALL
SELECT 'deliveries', count(*) FILTER (WHERE org_id = current_org()) FROM public.deliveries
UNION ALL
SELECT 'hos_logs', count(*) FILTER (WHERE org_id = current_org()) FROM public.hos_logs
UNION ALL
SELECT 'invoices', count(*) FILTER (WHERE org_id = current_org()) FROM public.invoices
UNION ALL
SELECT 'invoice_items', count(*) FILTER (WHERE org_id = current_org()) FROM public.invoice_items
UNION ALL
SELECT 'payrolls', count(*) FILTER (WHERE org_id = current_org()) FROM public.payrolls
UNION ALL
SELECT 'expenses', count(*) FILTER (WHERE org_id = current_org()) FROM public.expenses
UNION ALL
SELECT 'fuel_transactions', count(*) FILTER (WHERE org_id = current_org()) FROM public.fuel_transactions
UNION ALL
SELECT 'integration_tokens', count(*) FILTER (WHERE org_id = current_org()) FROM public.integration_tokens
UNION ALL
SELECT 'inbound_events', count(*) FILTER (WHERE org_id = current_org()) FROM public.inbound_events;

-- Tip: In CI, set request.jwt.claims with app_org_id to validate isolation via v_rls_check.
