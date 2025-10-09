-- 901_nearby_loads_rpc.sql
-- Prereqs: public.loads table
-- If not present, create a minimal table compatible with demo/smoke usage

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema='public' AND table_name='loads'
  ) THEN
    CREATE TABLE public.loads (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      org_id uuid NULL,
      origin_city text,
      dest_city text,
      pickup_lat double precision,
      pickup_lng double precision,
      miles numeric(8,1),
      rate_usd numeric(12,2),
      created_at timestamptz DEFAULT now()
    );
  END IF;
END$$;

-- Nearby loads RPC (haversine great-circle; radius in miles)
CREATE OR REPLACE FUNCTION public.nearby_loads(
  lat double precision,
  lng double precision,
  radius_miles double precision
)
RETURNS TABLE (
  id uuid,
  origin_city text,
  dest_city text,
  pickup_lat double precision,
  pickup_lng double precision,
  miles numeric,
  rate_usd numeric,
  distance_miles double precision
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH q AS (
    SELECT
      l.id, l.origin_city, l.dest_city, l.pickup_lat, l.pickup_lng, l.miles, l.rate_usd,
      3959 * acos(
        LEAST(1.0,
          cos(radians(lat)) * cos(radians(l.pickup_lat)) * cos(radians(l.pickup_lng) - radians(lng))
        + sin(radians(lat)) * sin(radians(l.pickup_lat))
        )
      ) AS distance_miles
    FROM public.loads l
    WHERE l.pickup_lat IS NOT NULL AND l.pickup_lng IS NOT NULL
  )
  SELECT id, origin_city, dest_city, pickup_lat, pickup_lng, miles, rate_usd, distance_miles
  FROM q
  WHERE distance_miles <= radius_miles
  ORDER BY distance_miles ASC NULLS LAST, pickup_lat NULLS LAST
  LIMIT 500
$$;

GRANT EXECUTE ON FUNCTION public.nearby_loads(double precision,double precision,double precision) TO authenticated;

-- Minimal RLS: enable with public-read (demo). Tighten for prod as needed.
ALTER TABLE public.loads ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='public' AND tablename='loads' AND policyname='loads_public_read'
  ) THEN
    CREATE POLICY loads_public_read ON public.loads FOR SELECT USING (true);
  END IF;
END $$;
