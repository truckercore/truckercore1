-- 2025-09-16_parking_ads_hardening.sql
-- High-impact fixes and improvements for Parking + Ads + Geospatial
-- This migration is transaction-safe and defensive: it checks table/column existence before altering.

begin;

set search_path = public;

-- 1) Geospatial: enable extensions for ll_to_earth/earth_distance
create extension if not exists cube;
create extension if not exists earthdistance;

-- 1.1) Functional GiST indexes for lat/lng tables if present
-- Helper DO block to create index only when table and columns exist
DO $$
DECLARE
  t record;
BEGIN
  FOR t IN (
    SELECT 'truckstops'::text AS tbl, 'lat'::text AS lat, 'lng'::text AS lng
    UNION ALL SELECT 'parking_stops','lat','lng'
  ) LOOP
    IF EXISTS (
      SELECT 1
      FROM information_schema.columns c1
      WHERE c1.table_schema = 'public' AND c1.table_name = t.tbl AND c1.column_name = t.lat
    ) AND EXISTS (
      SELECT 1
      FROM information_schema.columns c2
      WHERE c2.table_schema = 'public' AND c2.table_name = t.tbl AND c2.column_name = t.lng
    ) THEN
      EXECUTE format(
        'CREATE INDEX IF NOT EXISTS idx_%I_earth ON public.%I USING gist (ll_to_earth(%I, %I))',
        t.tbl, t.tbl, t.lat, t.lng
      );
    END IF;
  END LOOP;
END $$;

-- 2) Data quality and constraints
-- 2.1) ads: active_to > active_from; optional FK to truckstops(id); optional validations
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='ads') THEN
    -- add CHECK for time window
    IF NOT EXISTS (
      SELECT 1 FROM pg_constraint WHERE conname = 'ads_active_window_chk'
    ) THEN
      ALTER TABLE public.ads
        ADD CONSTRAINT ads_active_window_chk
        CHECK (active_to IS NULL OR active_from IS NULL OR active_to > active_from);
    END IF;

    -- optional radius clamp [1,250] if radius_km exists
    IF EXISTS (
      SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='ads' AND column_name='radius_km'
    ) AND NOT EXISTS (
      SELECT 1 FROM pg_constraint WHERE conname='ads_radius_km_chk'
    ) THEN
      ALTER TABLE public.ads
        ADD CONSTRAINT ads_radius_km_chk CHECK (radius_km IS NULL OR (radius_km >= 1 AND radius_km <= 250));
    END IF;

    -- optional roles subset if roles column is text[]
    IF EXISTS (
      SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='ads' AND column_name='roles' AND data_type='ARRAY'
    ) AND NOT EXISTS (
      SELECT 1 FROM pg_constraint WHERE conname='ads_roles_subset_chk'
    ) THEN
      ALTER TABLE public.ads
        ADD CONSTRAINT ads_roles_subset_chk CHECK (
          roles IS NULL OR roles <@ ARRAY['driver','ownerop']::text[]
        );
    END IF;

    -- FK stop_id -> truckstops(id) if both exist
    IF EXISTS (
      SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='ads' AND column_name='stop_id'
    ) AND EXISTS (
      SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='truckstops'
    ) AND NOT EXISTS (
      SELECT 1 FROM pg_constraint WHERE conname='ads_stop_id_fkey'
    ) THEN
      ALTER TABLE public.ads
        ADD CONSTRAINT ads_stop_id_fkey FOREIGN KEY (stop_id) REFERENCES public.truckstops(id) ON DELETE SET NULL;
    END IF;
  END IF;
END $$;

-- 2.2) parking_status checks: available counts >= 0; confidence within [0,1]
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='parking_status') THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='parking_status' AND column_name='available_estimate') AND
       NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='parking_status_available_estimate_chk') THEN
      ALTER TABLE public.parking_status
        ADD CONSTRAINT parking_status_available_estimate_chk CHECK (available_estimate IS NULL OR available_estimate >= 0);
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='parking_status' AND column_name='available_total') AND
       NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='parking_status_available_total_chk') THEN
      ALTER TABLE public.parking_status
        ADD CONSTRAINT parking_status_available_total_chk CHECK (available_total IS NULL OR available_total >= 0);
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='parking_status' AND column_name='confidence') AND
       NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='parking_status_confidence_chk') THEN
      ALTER TABLE public.parking_status
        ADD CONSTRAINT parking_status_confidence_chk CHECK (confidence IS NULL OR (confidence >= 0 AND confidence <= 1));
    END IF;
  END IF;
END $$;

-- 2.3) parking_reports: when kind='count', value must be not null and >=0
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='parking_reports') THEN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='parking_reports_count_value_chk') THEN
      ALTER TABLE public.parking_reports
        ADD CONSTRAINT parking_reports_count_value_chk
        CHECK (kind <> 'count' OR (value IS NOT NULL AND value >= 0));
    END IF;
  END IF;
END $$;

-- 3) Anti-spam write-rate limiting: partial unique indexes
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='parking_reports') THEN
    -- Per user per minute for driver-sourced
    CREATE UNIQUE INDEX IF NOT EXISTS ux_parking_reports_user_minute
      ON public.parking_reports (stop_id, user_id, date_trunc('minute', created_at))
      WHERE source = 'driver' AND user_id IS NOT NULL;

    -- Per device per minute for anonymous device submissions
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='parking_reports' AND column_name='device_hash') THEN
      CREATE UNIQUE INDEX IF NOT EXISTS ux_parking_reports_device_minute
        ON public.parking_reports (stop_id, device_hash, date_trunc('minute', created_at))
        WHERE device_hash IS NOT NULL;
    END IF;
  END IF;
END $$;

-- 4) updated_at triggers: reuse set_updated_at() or create it; attach to ads
-- Create helper if missing
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- Attach trigger to ads if table/column exists
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='ads' AND column_name='updated_at') THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_trigger WHERE tgname = 'trg_ads_set_updated_at'
    ) THEN
      CREATE TRIGGER trg_ads_set_updated_at
      BEFORE UPDATE ON public.ads
      FOR EACH ROW
      EXECUTE FUNCTION public.set_updated_at();
    END IF;
  END IF;
END $$;

-- 5) Masked free vs detailed paid: SECURITY DEFINER RPC returning masked fields
CREATE OR REPLACE FUNCTION public.parking_status_public_summary(
  p_stop_id uuid DEFAULT NULL,
  p_lat double precision DEFAULT NULL,
  p_lng double precision DEFAULT NULL,
  p_radius_km numeric DEFAULT NULL,
  p_limit int DEFAULT 50
) RETURNS TABLE (
  stop_id uuid,
  status_bucket text,
  confidence_rounded numeric,
  last_reported_by text,
  last_reported_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_have_geo boolean := (p_lat IS NOT NULL AND p_lng IS NOT NULL AND p_radius_km IS NOT NULL);
BEGIN
  IF p_stop_id IS NOT NULL THEN
    RETURN QUERY
    SELECT s.stop_id,
           CASE
             WHEN s.available_estimate IS NULL THEN 'unknown'
             WHEN s.available_total IS NOT NULL AND s.available_total > 0 THEN
               CASE
                 WHEN s.available_estimate::numeric / NULLIF(s.available_total::numeric,0) >= 0.66 THEN 'open'
                 WHEN s.available_estimate::numeric / NULLIF(s.available_total::numeric,0) >= 0.33 THEN 'limited'
                 ELSE 'full'
               END
             ELSE
               CASE WHEN s.available_estimate >= 10 THEN 'open' WHEN s.available_estimate >= 3 THEN 'limited' ELSE 'full' END
           END AS status_bucket,
           round(coalesce(s.confidence, 0)::numeric, 2) AS confidence_rounded,
           coalesce(s.last_reported_by, '') AS last_reported_by,
           s.last_reported_at
    FROM public.parking_status s
    WHERE s.stop_id = p_stop_id
    LIMIT 1;
  ELSIF v_have_geo THEN
    -- Geo filter via earth_box if we can find lat/lng in truckstops
    RETURN QUERY
    WITH nearby AS (
      SELECT ts.id AS stop_id
      FROM public.truckstops ts
      WHERE earth_box(ll_to_earth(p_lat, p_lng), (p_radius_km * 1000.0)) @> ll_to_earth(ts.lat, ts.lng)
      ORDER BY earth_distance(ll_to_earth(p_lat, p_lng), ll_to_earth(ts.lat, ts.lng))
      LIMIT p_limit
    )
    SELECT s.stop_id,
           CASE
             WHEN s.available_estimate IS NULL THEN 'unknown'
             WHEN s.available_total IS NOT NULL AND s.available_total > 0 THEN
               CASE
                 WHEN s.available_estimate::numeric / NULLIF(s.available_total::numeric,0) >= 0.66 THEN 'open'
                 WHEN s.available_estimate::numeric / NULLIF(s.available_total::numeric,0) >= 0.33 THEN 'limited'
                 ELSE 'full'
               END
             ELSE
               CASE WHEN s.available_estimate >= 10 THEN 'open' WHEN s.available_estimate >= 3 THEN 'limited' ELSE 'full' END
           END AS status_bucket,
           round(coalesce(s.confidence, 0)::numeric, 2) AS confidence_rounded,
           coalesce(s.last_reported_by, '') AS last_reported_by,
           s.last_reported_at
    FROM public.parking_status s
    JOIN nearby n ON n.stop_id = s.stop_id
    ORDER BY s.last_reported_at DESC NULLS LAST
    LIMIT p_limit;
  ELSE
    -- Fallback: return most recent p_limit rows (masked)
    RETURN QUERY
    SELECT s.stop_id,
           CASE
             WHEN s.available_estimate IS NULL THEN 'unknown'
             WHEN s.available_total IS NOT NULL AND s.available_total > 0 THEN
               CASE
                 WHEN s.available_estimate::numeric / NULLIF(s.available_total::numeric,0) >= 0.66 THEN 'open'
                 WHEN s.available_estimate::numeric / NULLIF(s.available_total::numeric,0) >= 0.33 THEN 'limited'
                 ELSE 'full'
               END
             ELSE
               CASE WHEN s.available_estimate >= 10 THEN 'open' WHEN s.available_estimate >= 3 THEN 'limited' ELSE 'full' END
           END AS status_bucket,
           round(coalesce(s.confidence, 0)::numeric, 2) AS confidence_rounded,
           coalesce(s.last_reported_by, '') AS last_reported_by,
           s.last_reported_at
    FROM public.parking_status s
    ORDER BY s.last_reported_at DESC NULLS LAST
    LIMIT p_limit;
  END IF;
END;
$$;

-- Ownership/grants hygiene for the new function
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_owner') THEN
    BEGIN ALTER FUNCTION public.parking_status_public_summary(uuid,double precision,double precision,numeric,int) OWNER TO app_owner; EXCEPTION WHEN others THEN NULL; END;
  END IF;
END $$;

REVOKE ALL ON FUNCTION public.parking_status_public_summary(uuid,double precision,double precision,numeric,int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.parking_status_public_summary(uuid,double precision,double precision,numeric,int) TO authenticated, service_role;

-- 6) Tighten ad_impressions/ad_clicks select policies (no leakage of NULL-user rows)
-- Enable RLS if not enabled and create SELECT-only policies for authenticated where user_id = auth.uid().
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='ad_impressions') THEN
    EXECUTE 'ALTER TABLE public.ad_impressions ENABLE ROW LEVEL SECURITY';
    IF NOT EXISTS (
      SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='ad_impressions' AND policyname='ad_impressions_select_own'
    ) THEN
      CREATE POLICY ad_impressions_select_own ON public.ad_impressions
        FOR SELECT TO authenticated
        USING (user_id = auth.uid());
    END IF;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='ad_clicks') THEN
    EXECUTE 'ALTER TABLE public.ad_clicks ENABLE ROW LEVEL SECURITY';
    IF NOT EXISTS (
      SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='ad_clicks' AND policyname='ad_clicks_select_own'
    ) THEN
      CREATE POLICY ad_clicks_select_own ON public.ad_clicks
        FOR SELECT TO authenticated
        USING (user_id = auth.uid());
    END IF;
  END IF;
END $$;

-- 7) Ads performance indexes
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='ads') THEN
    CREATE INDEX IF NOT EXISTS idx_ads_stop_time_priority ON public.ads (stop_id, active_from, active_to, priority);
    -- Partial index for currently active ads
    CREATE INDEX IF NOT EXISTS idx_ads_active_now ON public.ads (priority)
      WHERE now() BETWEEN active_from AND active_to;
  END IF;
END $$;

-- 8) Observability: audit table for parking_status transitions
CREATE TABLE IF NOT EXISTS public.parking_status_audit (
  id           bigint generated by default as identity primary key,
  at           timestamptz not null default now(),
  stop_id      uuid not null,
  source       text null,
  old_estimate integer null,
  new_estimate integer null,
  old_conf     numeric null,
  new_conf     numeric null,
  note         text null
);
CREATE INDEX IF NOT EXISTS idx_parking_status_audit_time ON public.parking_status_audit (at desc);
CREATE INDEX IF NOT EXISTS idx_parking_status_audit_stop ON public.parking_status_audit (stop_id);

-- Trigger to log changes when estimate/confidence changed
CREATE OR REPLACE FUNCTION public.trg_log_parking_status_audit()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.parking_status_audit(stop_id, source, old_estimate, new_estimate, old_conf, new_conf, note)
    VALUES(NEW.stop_id, NEW.last_reported_by, NULL, NEW.available_estimate, NULL, NEW.confidence, 'insert');
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    IF COALESCE(NEW.available_estimate, -1) <> COALESCE(OLD.available_estimate, -1)
       OR COALESCE(NEW.confidence, -1) <> COALESCE(OLD.confidence, -1) THEN
      INSERT INTO public.parking_status_audit(stop_id, source, old_estimate, new_estimate, old_conf, new_conf, note)
      VALUES(NEW.stop_id, NEW.last_reported_by, OLD.available_estimate, NEW.available_estimate, OLD.confidence, NEW.confidence, 'update');
    END IF;
    RETURN NEW;
  END IF;
  RETURN NEW;
END;
$$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='parking_status') THEN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='trg_parking_status_audit') THEN
      CREATE TRIGGER trg_parking_status_audit
      AFTER INSERT OR UPDATE ON public.parking_status
      FOR EACH ROW EXECUTE FUNCTION public.trg_log_parking_status_audit();
    END IF;
  END IF;
END $$;

commit;
