-- 20250924_parking_fuel_promo.sql
-- Purpose: Parking/Fuel/Promo schemas per spec, with enums/helpers, RLS policies, indexes, and views.
-- Idempotent and safe to re-run.

-- ========== Foundations (enums, helpers) ==========
DO $$ BEGIN
  CREATE TYPE public.source_kind AS ENUM ('crowd','operator','partner_api','sensor');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.pred_model AS ENUM ('parking_v1','parking_v2','fuel_v1');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.attribution_model AS ENUM ('last_touch','first_touch','time_decay','position_based');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Updated_at trigger (idempotent re-create OK)
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END $$;

-- Caller org helper (expects profiles(user_id, org_id))
CREATE OR REPLACE VIEW public._me AS
SELECT u.id AS user_id, p.org_id
FROM auth.users u
JOIN public.profiles p ON p.user_id = u.id
WHERE u.id = auth.uid();

-- ========== Parking data model ==========
-- Locations
CREATE TABLE IF NOT EXISTS public.parking_locations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL,
  name text NOT NULL,
  lat double precision NOT NULL,
  lng double precision NOT NULL,
  amenities jsonb NULL,
  capacity int NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
DO $$ BEGIN
  CREATE TRIGGER trg_parking_locations_u
  BEFORE UPDATE ON public.parking_locations
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
-- crude geo index using point(lng,lat)
DO $$ BEGIN
  PERFORM 1 FROM pg_indexes WHERE schemaname='public' AND indexname='parking_loc_geo_idx';
  IF NOT FOUND THEN
    EXECUTE 'CREATE INDEX parking_loc_geo_idx ON public.parking_locations USING gist (point(lng,lat))';
  END IF;
END $$;

-- Crowd/operator status pings
CREATE TABLE IF NOT EXISTS public.parking_status_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL,
  location_id uuid NOT NULL REFERENCES public.parking_locations(id) ON DELETE CASCADE,
  source public.source_kind NOT NULL,
  observed_at timestamptz NOT NULL DEFAULT now(),
  available_estimate int NULL,
  confidence numeric(4,3) NULL,
  meta jsonb NULL,
  created_by uuid NULL
);
CREATE INDEX IF NOT EXISTS parking_status_reports_loc_time_idx
  ON public.parking_status_reports(location_id, observed_at DESC);

-- Operator feed
CREATE TABLE IF NOT EXISTS public.parking_operator_status (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  operator_org_id uuid NOT NULL,
  location_id uuid NOT NULL REFERENCES public.parking_locations(id) ON DELETE CASCADE,
  observed_at timestamptz NOT NULL,
  available int NULL,
  meta jsonb NULL
);
CREATE INDEX IF NOT EXISTS parking_operator_status_idx
  ON public.parking_operator_status(location_id, observed_at DESC);

-- Predictions
CREATE TABLE IF NOT EXISTS public.parking_predictions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL,
  location_id uuid NOT NULL REFERENCES public.parking_locations(id) ON DELETE CASCADE,
  horizon_minutes int NOT NULL,
  predicted_for timestamptz NOT NULL,
  predicted_free int NULL,
  model public.pred_model NOT NULL DEFAULT 'parking_v1',
  model_version text NULL,
  features jsonb NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS parking_predictions_uk
  ON public.parking_predictions(org_id, location_id, predicted_for, model);

-- Truth
CREATE TABLE IF NOT EXISTS public.parking_truth (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  location_id uuid NOT NULL REFERENCES public.parking_locations(id) ON DELETE CASCADE,
  truth_time timestamptz NOT NULL,
  free_spots int NULL,
  collected_from uuid NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS parking_truth_loc_time_idx
  ON public.parking_truth(location_id, truth_time);

-- Views
CREATE OR REPLACE VIEW public.v_parking_now AS
WITH latest_report AS (
  SELECT DISTINCT ON (r.location_id)
         r.location_id, r.available_estimate, r.observed_at, r.source, r.confidence
  FROM public.parking_status_reports r
  ORDER BY r.location_id, r.observed_at DESC
),
latest_operator AS (
  SELECT DISTINCT ON (o.location_id)
         o.location_id, o.available AS operator_available, o.observed_at AS operator_observed_at
  FROM public.parking_operator_status o
  ORDER BY o.location_id, o.observed_at DESC
)
SELECT
  l.id AS location_id,
  l.name, l.lat, l.lng, l.capacity,
  lo.operator_available, lo.operator_observed_at,
  lr.available_estimate AS crowd_available, lr.observed_at AS crowd_observed_at,
  CASE
    WHEN lo.operator_observed_at IS NOT NULL
      AND (lr.observed_at IS NULL OR lo.operator_observed_at >= lr.observed_at)
      THEN lo.operator_available
    ELSE lr.available_estimate
  END AS best_available_now
FROM public.parking_locations l
LEFT JOIN latest_report lr ON lr.location_id = l.id
LEFT JOIN latest_operator lo ON lo.location_id = l.id;

CREATE OR REPLACE VIEW public.v_parking_pred_accuracy AS
SELECT
  p.location_id,
  p.model,
  p.predicted_for,
  p.predicted_free,
  t.free_spots AS truth_free,
  (p.predicted_free - t.free_spots) AS error_spots
FROM public.parking_predictions p
JOIN public.parking_truth t
  ON t.location_id = p.location_id
 AND t.truth_time BETWEEN p.predicted_for - interval '5 minutes' AND p.predicted_for + interval '5 minutes';

-- ========== Fuel model & route optimization scaffolding ==========
CREATE TABLE IF NOT EXISTS public.fuel_prices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL,
  station_id uuid NOT NULL,
  lat double precision NOT NULL,
  lng double precision NOT NULL,
  state_code char(2) NULL,
  brand text NULL,
  price_usd_per_gal numeric(6,3) NOT NULL,
  grade text NULL DEFAULT 'diesel',
  captured_at timestamptz NOT NULL DEFAULT now(),
  meta jsonb NULL
);
CREATE INDEX IF NOT EXISTS fuel_prices_station_time_idx
  ON public.fuel_prices(station_id, captured_at DESC);

CREATE TABLE IF NOT EXISTS public.vehicle_fuel_profile (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL,
  asset_id uuid NOT NULL,
  base_mpg numeric(5,2) NOT NULL DEFAULT 6.5,
  mpg_city numeric(5,2) NULL,
  mpg_highway numeric(5,2) NULL,
  tank_capacity_gal numeric(6,2) NOT NULL DEFAULT 150,
  reserve_gal numeric(6,2) NOT NULL DEFAULT 20,
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS vehicle_fuel_profile_uk
  ON public.vehicle_fuel_profile(org_id, asset_id);

CREATE TABLE IF NOT EXISTS public.fuel_refuel_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL,
  load_id uuid NOT NULL,
  asset_id uuid NOT NULL,
  planned_at timestamptz NOT NULL DEFAULT now(),
  total_cost_usd numeric(12,2) NOT NULL,
  total_gallons numeric(10,2) NOT NULL,
  details jsonb NOT NULL,
  assumptions jsonb NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS fuel_refuel_plans_uk
  ON public.fuel_refuel_plans(org_id, load_id);

CREATE OR REPLACE VIEW public.v_fuel_station_latest AS
SELECT DISTINCT ON (station_id)
  station_id, org_id, lat, lng, state_code, brand,
  price_usd_per_gal, captured_at
FROM public.fuel_prices
ORDER BY station_id, captured_at DESC;

-- ========== Promo & ROI attribution ==========
CREATE TABLE IF NOT EXISTS public.promos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL,
  name text NOT NULL,
  starts_at timestamptz NOT NULL,
  ends_at timestamptz NOT NULL,
  budget_usd numeric(12,2) NULL,
  target jsonb NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
DO $$ BEGIN
  CREATE TRIGGER trg_promos_u BEFORE UPDATE ON public.promos
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS public.promo_spend (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL,
  promo_id uuid NOT NULL REFERENCES public.promos(id) ON DELETE CASCADE,
  day date NOT NULL,
  spend_usd numeric(12,2) NOT NULL DEFAULT 0,
  meta jsonb NULL,
  UNIQUE (promo_id, day)
);

CREATE TABLE IF NOT EXISTS public.promo_impressions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  viewer_org_id uuid NOT NULL,
  promo_id uuid NOT NULL REFERENCES public.promos(id) ON DELETE CASCADE,
  user_id uuid NULL,
  seen_at timestamptz NOT NULL DEFAULT now(),
  context jsonb NULL
);
CREATE INDEX IF NOT EXISTS promo_impr_promo_time_idx
  ON public.promo_impressions(promo_id, seen_at DESC);

CREATE TABLE IF NOT EXISTS public.promo_conversions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  viewer_org_id uuid NOT NULL,
  promo_id uuid NOT NULL REFERENCES public.promos(id) ON DELETE CASCADE,
  user_id uuid NULL,
  converted_at timestamptz NOT NULL,
  conversion_kind text NOT NULL,
  amount_usd numeric(12,2) NULL,
  location_id uuid NULL,
  meta jsonb NULL
);
CREATE INDEX IF NOT EXISTS promo_conv_promo_time_idx
  ON public.promo_conversions(promo_id, converted_at DESC);

CREATE OR REPLACE VIEW public.v_promo_roi_daily AS
SELECT
  p.org_id AS advertiser_org_id,
  p.id AS promo_id,
  d::date AS day,
  COALESCE(s.spend_usd,0) AS spend_usd,
  COALESCE(i.impressions,0) AS impressions,
  COALESCE(c.conversions,0) AS conversions,
  COALESCE(c.revenue_usd,0) AS revenue_usd,
  CASE WHEN COALESCE(s.spend_usd,0) > 0
    THEN COALESCE(c.revenue_usd,0)/s.spend_usd
  END AS roi
FROM public.promos p
CROSS JOIN generate_series(date_trunc('day', p.starts_at)::date,
                           date_trunc('day', p.ends_at)::date, interval '1 day') d
LEFT JOIN (
  SELECT promo_id, day, sum(spend_usd) AS spend_usd
  FROM public.promo_spend
  GROUP BY 1,2
) s ON s.promo_id=p.id AND s.day = d
LEFT JOIN (
  SELECT promo_id, date_trunc('day', seen_at)::date AS day, count(*) AS impressions
  FROM public.promo_impressions
  GROUP BY 1,2
) i ON i.promo_id=p.id AND i.day = d
LEFT JOIN (
  SELECT promo_id, date_trunc('day', converted_at)::date AS day,
         count(*) AS conversions, sum(COALESCE(amount_usd,0)) AS revenue_usd
  FROM public.promo_conversions
  GROUP BY 1,2
) c ON c.promo_id=p.id AND c.day = d;

-- ========== RLS (org-scoped) ==========
ALTER TABLE public.parking_locations       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.parking_status_reports  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.parking_operator_status ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.parking_predictions     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.parking_truth           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fuel_prices             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicle_fuel_profile    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fuel_refuel_plans       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promos                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promo_spend             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promo_impressions       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promo_conversions       ENABLE ROW LEVEL SECURITY;

-- Generic policies per table
DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY[
    'parking_locations','parking_status_reports','parking_operator_status','parking_predictions','parking_truth',
    'fuel_prices','vehicle_fuel_profile','fuel_refuel_plans',
    'promos','promo_spend','promo_impressions','promo_conversions'
  ] LOOP
    EXECUTE format('CREATE POLICY IF NOT EXISTS sel_%I ON public.%I FOR SELECT USING (org_id = (SELECT org_id FROM public._me))', t, t);
    EXECUTE format('CREATE POLICY IF NOT EXISTS ins_%I ON public.%I FOR INSERT WITH CHECK (org_id = (SELECT org_id FROM public._me))', t, t);
    -- Updates for tables that have org_id
    EXECUTE format('CREATE POLICY IF NOT EXISTS upd_%I ON public.%I FOR UPDATE USING (org_id = (SELECT org_id FROM public._me))', t, t);
  END LOOP; END $$;

-- ========== Performance indexes (hot paths) ==========
CREATE INDEX IF NOT EXISTS parking_pred_lookup_idx
  ON public.parking_predictions(org_id, location_id, predicted_for DESC);

CREATE INDEX IF NOT EXISTS fuel_refuel_plans_lookup_idx
  ON public.fuel_refuel_plans(org_id, load_id);

CREATE INDEX IF NOT EXISTS promo_impr_viewer_idx
  ON public.promo_impressions(viewer_org_id, seen_at DESC);

CREATE INDEX IF NOT EXISTS promo_conv_viewer_idx
  ON public.promo_conversions(viewer_org_id, converted_at DESC);
