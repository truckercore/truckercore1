-- 1011_billing_retention.sql
-- Add data retention and performance indexes for billing logs/reports (resilient).

-- Indexes (if tables exist)
DO $$ BEGIN
  IF to_regclass('public.billing_reports') IS NOT NULL THEN
    EXECUTE 'create index if not exists idx_billing_reports_org_period on public.billing_reports(tenant_id, period_start, period_end)';
  END IF;
  IF to_regclass('public.billing_invoices') IS NOT NULL THEN
    EXECUTE 'create index if not exists idx_billing_invoices_org_period on public.billing_invoices(tenant_id, period_start, period_end)';
  END IF;
END $$;

-- Retention function (days)
CREATE OR REPLACE FUNCTION public.purge_billing_logs(p_days int DEFAULT 180)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=public
AS $$
DECLARE v_count int := 0; n int; BEGIN
  IF to_regclass('public.billing_reports') IS NOT NULL THEN
    EXECUTE format('delete from public.billing_reports where period_end < now() - interval ''%s days''', p_days) ;
    GET DIAGNOSTICS n = ROW_COUNT; v_count := v_count + COALESCE(n,0);
  END IF;
  IF to_regclass('public.billing_invoices') IS NOT NULL THEN
    EXECUTE format('delete from public.billing_invoices where period_end < now() - interval ''%s days''', p_days) ;
    GET DIAGNOSTICS n = ROW_COUNT; v_count := v_count + COALESCE(n,0);
  END IF;
  RETURN v_count;
END $$;