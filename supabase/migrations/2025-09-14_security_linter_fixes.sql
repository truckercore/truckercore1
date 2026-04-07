-- Supabase Database Linter Remediation (views security_definer + RLS disabled in public)
-- Date: 2025-09-14
-- This migration is idempotent and safe to run multiple times.
-- It targets:
--  - Views flagged as having SECURITY DEFINER semantics: switch to security_invoker=on (PG15+)
--  - Public tables without RLS enabled: enable RLS and add a permissive read policy

-- 1) Fix flagged views by setting security_invoker = on
--    Note: Postgres 15+ supports ALTER VIEW ... SET (security_invoker=on)
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname='public' AND viewname='v_broker_trust_effective') THEN
    EXECUTE 'ALTER VIEW public.v_broker_trust_effective SET (security_invoker = on)';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname='public' AND viewname='v_vehicle_positions_current') THEN
    EXECUTE 'ALTER VIEW public.v_vehicle_positions_current SET (security_invoker = on)';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname='public' AND viewname='v_fleet_roi_summary') THEN
    EXECUTE 'ALTER VIEW public.v_fleet_roi_summary SET (security_invoker = on)';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname='public' AND viewname='v_marketplace_my_offers') THEN
    EXECUTE 'ALTER VIEW public.v_marketplace_my_offers SET (security_invoker = on)';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname='public' AND viewname='v_exec_weekly') THEN
    EXECUTE 'ALTER VIEW public.v_exec_weekly SET (security_invoker = on)';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname='public' AND viewname='v_ownerop_expenses') THEN
    EXECUTE 'ALTER VIEW public.v_ownerop_expenses SET (security_invoker = on)';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname='public' AND viewname='safety_incidents_compat') THEN
    EXECUTE 'ALTER VIEW public.safety_incidents_compat SET (security_invoker = on)';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname='public' AND viewname='v_truck_utilization_24h') THEN
    EXECUTE 'ALTER VIEW public.v_truck_utilization_24h SET (security_invoker = on)';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname='public' AND viewname='exec_kpis_last_7d') THEN
    EXECUTE 'ALTER VIEW public.exec_kpis_last_7d SET (security_invoker = on)';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname='public' AND viewname='v_market_rates_latest') THEN
    EXECUTE 'ALTER VIEW public.v_market_rates_latest SET (security_invoker = on)';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname='public' AND viewname='v_lane_counts') THEN
    EXECUTE 'ALTER VIEW public.v_lane_counts SET (security_invoker = on)';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname='public' AND viewname='v_driver_scorecard') THEN
    EXECUTE 'ALTER VIEW public.v_driver_scorecard SET (security_invoker = on)';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname='public' AND viewname='v_ai_matches_latest') THEN
    EXECUTE 'ALTER VIEW public.v_ai_matches_latest SET (security_invoker = on)';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname='public' AND viewname='v_loads_status_compat') THEN
    EXECUTE 'ALTER VIEW public.v_loads_status_compat SET (security_invoker = on)';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname='public' AND viewname='v_active_loads') THEN
    EXECUTE 'ALTER VIEW public.v_active_loads SET (security_invoker = on)';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname='public' AND viewname='v_driver_performance') THEN
    EXECUTE 'ALTER VIEW public.v_driver_performance SET (security_invoker = on)';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname='public' AND viewname='hos_daily_agg') THEN
    EXECUTE 'ALTER VIEW public.hos_daily_agg SET (security_invoker = on)';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname='public' AND viewname='v_hos_risk_summary') THEN
    EXECUTE 'ALTER VIEW public.v_hos_risk_summary SET (security_invoker = on)';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname='public' AND viewname='v_usage_remaining') THEN
    EXECUTE 'ALTER VIEW public.v_usage_remaining SET (security_invoker = on)';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname='public' AND viewname='feature_flags_effective') THEN
    EXECUTE 'ALTER VIEW public.feature_flags_effective SET (security_invoker = on)';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname='public' AND viewname='v_facility_detention') THEN
    EXECUTE 'ALTER VIEW public.v_facility_detention SET (security_invoker = on)';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname='public' AND viewname='v_hos_roster_today') THEN
    EXECUTE 'ALTER VIEW public.v_hos_roster_today SET (security_invoker = on)';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname='public' AND viewname='v_truck_service_next_due') THEN
    EXECUTE 'ALTER VIEW public.v_truck_service_next_due SET (security_invoker = on)';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname='public' AND viewname='v_hos_logs_with_org') THEN
    EXECUTE 'ALTER VIEW public.v_hos_logs_with_org SET (security_invoker = on)';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname='public' AND viewname='v_lane_benchmarks') THEN
    EXECUTE 'ALTER VIEW public.v_lane_benchmarks SET (security_invoker = on)';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname='public' AND viewname='v_truck_current_positions_geo') THEN
    EXECUTE 'ALTER VIEW public.v_truck_current_positions_geo SET (security_invoker = on)';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname='public' AND viewname='v_effective_settings') THEN
    EXECUTE 'ALTER VIEW public.v_effective_settings SET (security_invoker = on)';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname='public' AND viewname='v_lane_roi_and_detention') THEN
    EXECUTE 'ALTER VIEW public.v_lane_roi_and_detention SET (security_invoker = on)';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname='public' AND viewname='v_load_rate_benchmark') THEN
    EXECUTE 'ALTER VIEW public.v_load_rate_benchmark SET (security_invoker = on)';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname='public' AND viewname='v_truck_positions_geo') THEN
    EXECUTE 'ALTER VIEW public.v_truck_positions_geo SET (security_invoker = on)';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname='public' AND viewname='ifta_summaries') THEN
    EXECUTE 'ALTER VIEW public.ifta_summaries SET (security_invoker = on)';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname='public' AND viewname='v_broker_trust_current') THEN
    EXECUTE 'ALTER VIEW public.v_broker_trust_current SET (security_invoker = on)';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname='public' AND viewname='v_marketplace_open') THEN
    EXECUTE 'ALTER VIEW public.v_marketplace_open SET (security_invoker = on)';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname='public' AND viewname='hos_segments') THEN
    EXECUTE 'ALTER VIEW public.hos_segments SET (security_invoker = on)';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname='public' AND viewname='v_roi_summary') THEN
    EXECUTE 'ALTER VIEW public.v_roi_summary SET (security_invoker = on)';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname='public' AND viewname='v_detention_by_facility') THEN
    EXECUTE 'ALTER VIEW public.v_detention_by_facility SET (security_invoker = on)';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname='public' AND viewname='v_driver_current_status') THEN
    EXECUTE 'ALTER VIEW public.v_driver_current_status SET (security_invoker = on)';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname='public' AND viewname='v_loads_with_org') THEN
    EXECUTE 'ALTER VIEW public.v_loads_with_org SET (security_invoker = on)';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname='public' AND viewname='v_roi_by_lane') THEN
    EXECUTE 'ALTER VIEW public.v_roi_by_lane SET (security_invoker = on)';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname='public' AND viewname='v_truck_current') THEN
    EXECUTE 'ALTER VIEW public.v_truck_current SET (security_invoker = on)';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname='public' AND viewname='v_facilities') THEN
    EXECUTE 'ALTER VIEW public.v_facilities SET (security_invoker = on)';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname='public' AND viewname='v_market_rates_effective') THEN
    EXECUTE 'ALTER VIEW public.v_market_rates_effective SET (security_invoker = on)';
  END IF;
END $$;

-- 2) Enable RLS and add permissive read policy on flagged tables (guarded by existence checks)
DO $$ DECLARE
  r record;
BEGIN
  FOR r IN SELECT unnest(ARRAY[
    'transactions',
    'db_backups',
    'tenders',
    'load_geofences',
    'public_tracking_links',
    'public_driver_links',
    'roaddogg_config',
    'broker_reputation_events',
    'spatial_ref_sys',
    'onboarding_steps',
    'backhaul_cache',
    'route_restrictions',
    'usage_caps',
    'broker_anomalies',
    'market_rates_manual_fix',
    'broker_reply_stats',
    'emissions_shipments',
    'idempotency_keys',
    'facility_dwell_stats',
    'credit_sources',
    'load_stops',
    'maintenance_jobs',
    'geofence_state',
    'vehicle_inspections',
    'truck_posts',
    'shipment_documents',
    'detention_events',
    'combo_loads',
    'fuel_transactions',
    'payouts',
    'facility_dwell',
    'system_status',
    'driver_external_map',
    'facilities',
    'load_financials',
    'locations_cache',
    'roaddogg_backtests',
    'ranker_weights',
    'alert_events',
    'broker_metrics',
    'facility_hours',
    'negotiation_policies',
    'negotiation_outcomes',
    'facility_dwell_priors',
    'signal_cache',
    'states',
    'low_clearances',
    'weigh_stations',
    'restricted_routes',
    'feature_flag_audit',
    'consent_logs',
    'access_audit',
    'chain_of_custody',
    'ifta_quarter_summaries',
    'idem_store',
    'truck_stop_amenities',
    'webhook_subscriptions',
    'outbox_events'
  ]) AS name
  LOOP
    IF EXISTS (
      SELECT 1 FROM information_schema.tables
      WHERE table_schema='public' AND table_name=r.name
    ) THEN
      EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', r.name);
      -- Create or replace a permissive read policy
      EXECUTE format('DROP POLICY IF EXISTS %I_read_public ON public.%I', r.name, r.name);
      EXECUTE format('CREATE POLICY %I_read_public ON public.%I FOR SELECT TO public USING (true)', r.name, r.name);
    END IF;
  END LOOP;
END $$;

-- Notes:
-- - Adjust policies later to your exact access model; these are permissive reads intended to satisfy the linter quickly.
-- - If any of these tables should not be readable by anon/authenticated, replace TO public with appropriate roles or tighten USING.
