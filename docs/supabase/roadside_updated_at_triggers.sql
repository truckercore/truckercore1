-- docs/supabase/roadside_updated_at_triggers.sql
-- Enforce updated_at trigger on selected roadside/telemetry tables for consistency.
-- Idempotent and safe to re-run.

create extension if not exists pgcrypto;

-- Generic updated_at trigger
create or replace function public.tg_set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

-- Apply to known tables (add column if missing; then attach trigger if missing)
DO $$
BEGIN
  -- poi_reports
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='poi_reports' AND column_name='updated_at'
  ) THEN
    BEGIN
      EXECUTE 'ALTER TABLE public.poi_reports ADD COLUMN updated_at timestamptz NOT NULL DEFAULT now()';
    EXCEPTION WHEN undefined_table THEN
      -- table may not exist in this deployment; ignore
      NULL;
    END;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='poi_reports')
     AND NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='trg_poi_reports_updated_at') THEN
    EXECUTE 'CREATE TRIGGER trg_poi_reports_updated_at BEFORE UPDATE ON public.poi_reports FOR EACH ROW EXECUTE FUNCTION public.tg_set_updated_at()';
  END IF;

  -- parking_status
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='parking_status' AND column_name='updated_at'
  ) THEN
    BEGIN
      EXECUTE 'ALTER TABLE public.parking_status ADD COLUMN updated_at timestamptz NOT NULL DEFAULT now()';
    EXCEPTION WHEN undefined_table THEN NULL; END;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='parking_status')
     AND NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='trg_parking_status_updated_at') THEN
    EXECUTE 'CREATE TRIGGER trg_parking_status_updated_at BEFORE UPDATE ON public.parking_status FOR EACH ROW EXECUTE FUNCTION public.tg_set_updated_at()';
  END IF;

  -- weigh_station_state
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='weigh_station_state' AND column_name='updated_at'
  ) THEN
    BEGIN
      EXECUTE 'ALTER TABLE public.weigh_station_state ADD COLUMN updated_at timestamptz NOT NULL DEFAULT now()';
    EXCEPTION WHEN undefined_table THEN NULL; END;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='weigh_station_state')
     AND NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='trg_weigh_station_state_updated_at') THEN
    EXECUTE 'CREATE TRIGGER trg_weigh_station_state_updated_at BEFORE UPDATE ON public.weigh_station_state FOR EACH ROW EXECUTE FUNCTION public.tg_set_updated_at()';
  END IF;
END $$;
