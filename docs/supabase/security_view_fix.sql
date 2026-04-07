-- Security View Remediation for Supabase Database Linter (SECURITY DEFINER on views)
-- Run this after applying the base schemas. Safe to run multiple times.
-- What this script does:
-- 1) Recreate certain views without SECURITY DEFINER semantics (plain CREATE OR REPLACE VIEW).
--    These views rely on underlying tables that already enforce RLS.
-- 2) Guard for PostGIS/geofencing dependent items (only run if tables exist).
-- 3) Address linter: enable RLS on public.spatial_ref_sys and add a permissive read policy.
-- 4) Optionally drop legacy fuel_monthly_agg if it exists.

-- 0) Optional: Drop legacy fuel_monthly_agg if present (we don't recreate it here)
DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.views
    WHERE table_schema='public' AND table_name='fuel_monthly_agg'
  ) THEN
    EXECUTE 'DROP VIEW IF EXISTS public.fuel_monthly_agg';
  END IF;
END $$;

-- 1) Recreate v_truck_service_next_due as plain view (no SECURITY DEFINER on views)
-- Only if its base tables exist
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='truck_service_schedules') THEN
    EXECUTE $view$
      CREATE OR REPLACE VIEW public.v_truck_service_next_due AS
      SELECT
        s.id AS schedule_id,
        s.org_id,
        s.truck_id,
        s.task_id,
        s.interval_days,
        s.interval_odometer_km,
        s.interval_engine_hours,
        s.last_service_at,
        s.last_service_odometer_km,
        s.last_service_engine_hours,
        tcp.odometer_km AS current_odometer_km,
        CASE
          WHEN s.interval_odometer_km IS NOT NULL AND s.last_service_odometer_km IS NOT NULL
            THEN (s.last_service_odometer_km + s.interval_odometer_km) - COALESCE(tcp.odometer_km, s.last_service_odometer_km)
          ELSE NULL
        END AS km_to_due,
        CASE
          WHEN s.interval_days IS NOT NULL AND s.last_service_at IS NOT NULL
            THEN (s.last_service_at + make_interval(days => s.interval_days)) - now()
          ELSE NULL
        END AS time_to_due
      FROM public.truck_service_schedules s
      LEFT JOIN public.truck_current_positions tcp ON tcp.truck_id = s.truck_id;
    $view$;
  END IF;
END $$;

-- 2) Recreate PostGIS-related views only if required tables exist
-- v_truck_positions_geo
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='truck_positions') THEN
    EXECUTE $view$
      CREATE OR REPLACE VIEW public.v_truck_positions_geo AS
      SELECT
        p.id,
        p.truck_id,
        ST_SetSRID(ST_MakePoint(p.lng, p.lat),4326)::geography AS position,
        p.lat,
        p.lng,
        p.speed_kph,
        p.heading_deg,
        p.odometer_km,
        p.gps_ts,
        p.source,
        p.created_at
      FROM public.truck_positions p;
    $view$;
  END IF;
END $$;

-- v_truck_current_positions_geo
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='truck_current_positions') THEN
    EXECUTE $view$
      CREATE OR REPLACE VIEW public.v_truck_current_positions_geo AS
      SELECT
        cp.truck_id,
        ST_SetSRID(ST_MakePoint(cp.lng, cp.lat),4326)::geography AS position,
        cp.lat,
        cp.lng,
        cp.speed_kph,
        cp.heading_deg,
        cp.odometer_km,
        cp.gps_ts,
        cp.updated_at
      FROM public.truck_current_positions cp;
    $view$;
  END IF;
END $$;

-- v_trucks_in_geofences
DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='trucks'
  ) AND EXISTS (
    SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='truck_current_positions'
  ) AND EXISTS (
    SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='geofences'
  ) THEN
    EXECUTE $view$
      CREATE OR REPLACE VIEW public.v_trucks_in_geofences AS
      SELECT
        t.id AS truck_id,
        g.id AS geofence_id,
        g.name AS geofence_name,
        cp.lat,
        cp.lng,
        cp.gps_ts
      FROM public.trucks t
      JOIN public.truck_current_positions cp ON cp.truck_id = t.id
      JOIN public.geofences g ON g.carrier_id = t.carrier_id
      WHERE ST_Contains(g.area::geometry, ST_SetSRID(ST_MakePoint(cp.lng, cp.lat),4326)::geometry);
    $view$;
  END IF;
END $$;

-- 3) v_truck_current (plain view)
DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='trucks'
  ) THEN
    EXECUTE $view$
      CREATE OR REPLACE VIEW public.v_truck_current AS
      SELECT
        t.id AS truck_id,
        t.external_id,
        t.vin,
        t.plate,
        t.status AS truck_status,
        cp.lat,
        cp.lng,
        cp.speed_kph,
        cp.heading_deg,
        cp.gps_ts,
        a.id AS assignment_id,
        a.status AS assignment_status,
        a.order_id,
        a.leg_id
      FROM public.trucks t
      LEFT JOIN public.truck_current_positions cp ON cp.truck_id = t.id
      LEFT JOIN LATERAL (
        SELECT a1.*
        FROM public.assignments a1
        WHERE a1.truck_id = t.id AND a1.status IN ('planned','assigned','en_route','at_pickup','at_dropoff')
        ORDER BY COALESCE(a1.started_at, a1.assigned_at) DESC
        LIMIT 1
      ) a ON TRUE;
    $view$;
  END IF;
END $$;

-- 4) RLS on public.spatial_ref_sys
-- Some linters require RLS enabled on all public tables even if read-only system tables.
DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='spatial_ref_sys'
  ) THEN
    EXECUTE 'ALTER TABLE public.spatial_ref_sys ENABLE ROW LEVEL SECURITY';
    -- Permissive read policy for all roles (anon/authenticated). Adjust to your needs.
    EXECUTE 'DROP POLICY IF EXISTS spatial_ref_sys_read ON public.spatial_ref_sys';
    EXECUTE 'CREATE POLICY spatial_ref_sys_read ON public.spatial_ref_sys FOR SELECT USING (true)';
  END IF;
END $$;

-- Notes:
-- - Views in Postgres do not have SECURITY INVOKER/DEFINER like functions. If your project had a prior view created with an extension that set a definer attribute, recreating it via plain CREATE OR REPLACE VIEW removes that.
-- - Functions like public.fn_refresh_reporting() or RPC wrappers may remain SECURITY DEFINER by design; they are not part of this linter item about views.
