-- docs/supabase/poi_core_schema.sql
-- Minimal POIs schema to support bbox queries for parking/weigh state endpoints.
-- Safe to re-run.

create extension if not exists pgcrypto;

-- Create a lightweight enum for kind if not present
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'poi_kind') THEN
    CREATE TYPE public.poi_kind AS ENUM ('truck_stop','parking','weigh_station','repair','rest_area','other');
  END IF;
END $$;

-- Base POIs table (if not already present in another form like points_of_interest)
CREATE TABLE IF NOT EXISTS public.pois (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text,
  kind public.poi_kind NOT NULL DEFAULT 'other',
  lat double precision NOT NULL,
  lng double precision NOT NULL,
  org_id uuid NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Simple bbox-friendly btree indexes; if PostGIS enabled, prefer gist geography index
CREATE INDEX IF NOT EXISTS idx_pois_kind ON public.pois(kind);
CREATE INDEX IF NOT EXISTS idx_pois_lat ON public.pois(lat);
CREATE INDEX IF NOT EXISTS idx_pois_lng ON public.pois(lng);

-- Optional: spatial index using earthdistance if available
-- CREATE EXTENSION IF NOT EXISTS cube;
-- CREATE EXTENSION IF NOT EXISTS earthdistance;
-- CREATE INDEX IF NOT EXISTS idx_pois_earth ON public.pois USING gist (ll_to_earth(lat,lng));

-- No RLS by default here; enable and scope as needed in your project.
