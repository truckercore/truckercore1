-- 905_rollups.sql
-- Daily rollup function and table

CREATE TABLE IF NOT EXISTS public.org_metrics_daily (
  org_id uuid NOT NULL,
  date date NOT NULL,
  miles numeric(12,2) NOT NULL DEFAULT 0,
  revenue_usd numeric(12,2) NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  PRIMARY KEY (org_id, date)
);

CREATE OR REPLACE FUNCTION public.rollup_org_metrics_daily()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.org_metrics_daily(org_id, date, miles, revenue_usd)
  SELECT p.org_id,
         (now() - interval '1 day')::date AS date,
         COALESCE(SUM(t.total_miles),0)::numeric(12,2) AS miles,
         COALESCE(SUM(r.amount_usd),0)::numeric(12,2) AS revenue_usd
  FROM public.profiles p
  LEFT JOIN public.ifta_trips t
    ON t.org_id = p.org_id
   AND t.ended_at::date = (now() - interval '1 day')::date
  LEFT JOIN public.load_revenue r
    ON r.org_id = p.org_id
   AND r.created_at::date = (now() - interval '1 day')::date
  GROUP BY 1,2
  ON CONFLICT (org_id, date) DO UPDATE
    SET miles = EXCLUDED.miles,
        revenue_usd = EXCLUDED.revenue_usd;
END
$$;