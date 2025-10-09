-- 1010_billing_dashboards.sql
-- Resilient dashboard views for billing (safe when tables not present)

-- Active seats by tenant
DO $$ BEGIN
  IF to_regclass('public.billing_seats') IS NOT NULL THEN
    EXECUTE $$
      CREATE OR REPLACE VIEW public.billing_active_seats_by_org AS
      SELECT org_id, COALESCE(active_seats,0) AS active_seats
      FROM public.billing_seats
      ORDER BY active_seats DESC;
    $$;
  ELSE
    EXECUTE $$
      CREATE OR REPLACE VIEW public.billing_active_seats_by_org AS
      SELECT NULL::uuid AS org_id, 0::int AS active_seats WHERE 1=0;
    $$;
  END IF;
END $$;

-- Entitled vs provisioned seats (by tenant)
DO $$ BEGIN
  IF to_regclass('public.billing_entitlements') IS NOT NULL AND to_regclass('public.billing_seats') IS NOT NULL THEN
    EXECUTE $$
      CREATE OR REPLACE VIEW public.billing_entitled_vs_provisioned AS
      SELECT e.org_id,
             COALESCE(e.entitled_seats,0) AS entitled,
             COALESCE(s.active_seats,0) AS provisioned,
             GREATEST(COALESCE(s.active_seats,0) - COALESCE(e.entitled_seats,0), 0) AS drift
      FROM public.billing_entitlements e
      LEFT JOIN public.billing_seats s ON s.org_id=e.org_id
      ORDER BY drift DESC, entitled DESC;
    $$;
  ELSE
    EXECUTE $$
      CREATE OR REPLACE VIEW public.billing_entitled_vs_provisioned AS
      SELECT NULL::uuid AS org_id, 0::int AS entitled, 0::int AS provisioned, 0::int AS drift WHERE 1=0;
    $$;
  END IF;
END $$;

-- Drift over time (daily counts)
DO $$ BEGIN
  IF to_regclass('public.billing_recon_log') IS NOT NULL THEN
    EXECUTE $$
      CREATE OR REPLACE VIEW public.billing_drift_daily AS
      SELECT date_trunc('day', created_at) AS day,
             SUM(drift_count) AS total_drift
      FROM public.billing_recon_log
      WHERE created_at >= now() - interval '30 days'
      GROUP BY 1
      ORDER BY 1 DESC;
    $$;
  ELSE
    EXECUTE $$
      CREATE OR REPLACE VIEW public.billing_drift_daily AS
      SELECT now()::date AS day, 0::int AS total_drift WHERE 1=0;
    $$;
  END IF;
END $$;
