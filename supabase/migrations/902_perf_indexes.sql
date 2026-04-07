-- 902_perf_indexes.sql
-- Create indexes conditionally to avoid failures in environments missing tables/columns

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='ifta_trips' AND column_name='ended_at'
  ) THEN
    CREATE INDEX IF NOT EXISTS idx_ifta_trips_org_ended ON public.ifta_trips(org_id, ended_at);
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='ifta_fuel_purchases' AND column_name='purchased_at'
  ) THEN
    CREATE INDEX IF NOT EXISTS idx_ifta_fuel_org_time ON public.ifta_fuel_purchases(org_id, purchased_at);
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='expenses' AND column_name='occurred_at'
  ) THEN
    CREATE INDEX IF NOT EXISTS idx_expenses_org_time ON public.expenses(org_id, occurred_at);
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='payout_requests' AND column_name='status'
  ) THEN
    CREATE INDEX IF NOT EXISTS idx_payouts_org_status ON public.payout_requests(org_id, status, created_at);
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='lane_rates' AND column_name='observed_at'
  ) THEN
    CREATE INDEX IF NOT EXISTS idx_lane_rates_od_time ON public.lane_rates(origin_geo, dest_geo, observed_at);
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema='public' AND table_name='lane_forecasts'
  ) THEN
    CREATE INDEX IF NOT EXISTS idx_lane_fc_od ON public.lane_forecasts(origin_geo, dest_geo);
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='hos_events' AND column_name='started_at'
  ) THEN
    CREATE INDEX IF NOT EXISTS idx_hos_driver_time ON public.hos_events(driver_id, started_at);
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='geofence_events' AND column_name='occurred_at'
  ) THEN
    CREATE INDEX IF NOT EXISTS idx_geofence_events_org_time ON public.geofence_events(org_id, occurred_at);
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema='public' AND table_name='community_posts'
  ) THEN
    CREATE INDEX IF NOT EXISTS idx_comm_posts_time ON public.community_posts(created_at);
  END IF;
END$$;
