-- 20250924_system_events_enhancements.sql
-- Purpose: Bring system_events in line with rollup/alerts usage. Adds occurred_at+compat columns,
-- indexes, retention function, rollup/freshness/gaps views, and optional MV and SSO view.
-- Safe to re-run (idempotent) and backward-compatible with existing system_events triggers.

-- 1) Table shape enhancements (non-destructive)
DO $$
BEGIN
  IF to_regclass('public.system_events') IS NULL THEN
    -- Create minimal table if absent (keep compatible columns)
    EXECUTE $$
      create table public.system_events (
        id uuid primary key default gen_random_uuid(),
        org_id uuid not null,
        event_code text null,
        code text null,
        entity_kind text null,
        entity text null,
        entity_id text not null,
        meta jsonb not null default '{}'::jsonb,
        details jsonb not null default '{}'::jsonb,
        actor_id uuid null,
        occurred_at timestamptz not null default now(),
        triggered_at timestamptz not null default now()
      );
    $$;
  ELSE
    -- Add missing columns to existing table
    BEGIN ALTER TABLE public.system_events ADD COLUMN IF NOT EXISTS occurred_at timestamptz not null default now(); EXCEPTION WHEN others THEN NULL; END;
    BEGIN ALTER TABLE public.system_events ADD COLUMN IF NOT EXISTS actor_id uuid; EXCEPTION WHEN others THEN NULL; END;
    BEGIN ALTER TABLE public.system_events ADD COLUMN IF NOT EXISTS event_code text; EXCEPTION WHEN others THEN NULL; END;
    BEGIN ALTER TABLE public.system_events ADD COLUMN IF NOT EXISTS entity_kind text; EXCEPTION WHEN others THEN NULL; END;
    BEGIN ALTER TABLE public.system_events ADD COLUMN IF NOT EXISTS meta jsonb not null default '{}'::jsonb; EXCEPTION WHEN others THEN NULL; END;
    -- Keep legacy columns (code/entity/details/triggered_at) for compatibility
  END IF;
END $$;

-- 2) RLS ensure (read-only to org)
ALTER TABLE public.system_events ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='system_events' AND policyname='sys_events_read_org'
  ) THEN
    CREATE POLICY sys_events_read_org ON public.system_events
    FOR SELECT TO authenticated
    USING (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
  END IF;
END $$;

-- 3) Helpful indexes (idempotent)
CREATE INDEX IF NOT EXISTS se_org_ts_idx  ON public.system_events (org_id, occurred_at desc);
CREATE INDEX IF NOT EXISTS se_code_ts_idx ON public.system_events (event_code, occurred_at desc);
CREATE INDEX IF NOT EXISTS se_entity_idx  ON public.system_events (entity_kind, entity_id);

-- 4) Retention function (server-side job can call this)
CREATE OR REPLACE FUNCTION public.prune_system_events(days int DEFAULT 90)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM public.system_events
   WHERE occurred_at < now() - make_interval(days => days);
END $$;

-- 5) Metrics rollups and health
-- 5.1 v_metrics_rollup (rename day->date to match consumer queries)
CREATE OR REPLACE VIEW public.v_metrics_rollup AS
WITH days AS (
  SELECT generate_series(date_trunc('day', now()) - interval '30 days', date_trunc('day', now()), interval '1 day')::date AS date
),
events AS (
  SELECT
    org_id,
    date_trunc('day', occurred_at)::date AS date,
    sum(CASE WHEN coalesce(event_code, code)='exception.raised' THEN 1 ELSE 0 END) AS exceptions_raised,
    sum(CASE WHEN coalesce(event_code, code)='exception.resolved' THEN 1 ELSE 0 END) AS exceptions_resolved,
    sum(CASE WHEN coalesce(event_code, code)='invoice.status.change' AND (coalesce(meta,details)->>'to') IN ('sent','partial','paid','void') THEN 1 ELSE 0 END) AS invoices_moved,
    sum(CASE WHEN coalesce(event_code, code)='document.uploaded' THEN 1 ELSE 0 END) AS documents_uploaded,
    sum(CASE WHEN coalesce(event_code, code)='ocr.completed' THEN 1 ELSE 0 END) AS ocr_completed
  FROM public.system_events
  WHERE occurred_at >= now() - interval '31 days'
  GROUP BY 1,2
),
loads_rollup AS (
  SELECT org_id,
         date_trunc('day', created_at)::date AS date,
         count(*) FILTER (WHERE status IN ('tendered','accepted')) AS loads_posted,
         0::bigint AS loads_assigned
  FROM public.loads
  WHERE created_at >= now() - interval '31 days'
  GROUP BY 1,2
),
assignments_rollup AS (
  SELECT org_id,
         date_trunc('day', assigned_at)::date AS date,
         count(*) AS loads_assigned
  FROM public.assignments
  WHERE assigned_at >= now() - interval '31 days'
  GROUP BY 1,2
),
invoices_rollup AS (
  SELECT org_id,
         date_trunc('day', COALESCE(issued_at, created_at, now()))::date AS date,
         count(*) AS invoices_created,
         SUM(COALESCE(amount_due_usd,0))::numeric(20,2) AS invoice_amount_usd
  FROM public.invoices
  WHERE COALESCE(issued_at, created_at, now()) >= now() - interval '31 days'
  GROUP BY 1,2
)
SELECT
  COALESCE(e.org_id, l.org_id, a.org_id, i.org_id) AS org_id,
  d.date,
  COALESCE(e.exceptions_raised,0) AS exceptions_raised,
  COALESCE(e.exceptions_resolved,0) AS exceptions_resolved,
  COALESCE(e.documents_uploaded,0) AS documents_uploaded,
  COALESCE(e.ocr_completed,0) AS ocr_completed,
  COALESCE(l.loads_posted,0) AS loads_posted,
  COALESCE(a.loads_assigned, l.loads_assigned, 0) AS loads_assigned,
  COALESCE(i.invoices_created,0) AS invoices_created,
  COALESCE(i.invoice_amount_usd,0)::numeric(20,2) AS invoice_amount_usd
FROM days d
LEFT JOIN events e ON e.date = d.date
LEFT JOIN loads_rollup l ON l.date = d.date AND l.org_id = e.org_id
LEFT JOIN assignments_rollup a ON a.date = d.date AND a.org_id = COALESCE(e.org_id,l.org_id)
LEFT JOIN invoices_rollup i ON i.date = d.date AND i.org_id = COALESCE(e.org_id,l.org_id,a.org_id);

-- 5.2 Extended rollup with P95 assignment time and counts
CREATE OR REPLACE VIEW public.v_metrics_rollup_extended AS
WITH assign AS (
  SELECT org_id, entity_id::uuid AS load_id,
         min(occurred_at) FILTER (WHERE coalesce(event_code, code)='load.created') AS t_created,
         min(occurred_at) FILTER (WHERE coalesce(event_code, code)='assignment.created') AS t_assigned
  FROM public.metrics_events
  WHERE ts >= now() - interval '35 days'
  GROUP BY org_id, entity_id
),
deltas AS (
  SELECT org_id,
         date_trunc('day', t_assigned) AS date,
         extract(epoch FROM (t_assigned - t_created)) AS sec_to_assign
  FROM assign
  WHERE t_created IS NOT NULL AND t_assigned IS NOT NULL
)
SELECT org_id,
       date::date,
       percentile_cont(0.95) WITHIN GROUP (ORDER BY sec_to_assign) AS p95_assign_s,
       count(*) AS n_assigns
FROM deltas
GROUP BY org_id, date;

-- 5.3 Freshness and gaps
CREATE OR REPLACE VIEW public.system_events_freshness AS
SELECT org_id, now() - max(occurred_at) AS lag
FROM public.system_events
GROUP BY org_id;

CREATE OR REPLACE VIEW public.system_events_gaps AS
WITH days AS (
  SELECT generate_series(current_date - interval '14 days', current_date, interval '1 day')::date d
),
byday AS (
  SELECT org_id, occurred_at::date d, count(*) c
  FROM public.system_events
  WHERE occurred_at >= current_date - interval '14 days'
  GROUP BY 1,2
)
SELECT o.org_id, d.d AS date_missing
FROM (SELECT DISTINCT org_id FROM public.system_events) o
CROSS JOIN days d
LEFT JOIN byday b ON b.org_id=o.org_id AND b.d=d.d
WHERE coalesce(b.c,0)=0;

-- 5.4 Events per day heartbeat
CREATE OR REPLACE VIEW public.v_system_events_per_day AS
SELECT occurred_at::date AS date, org_id, count(*) AS events
FROM public.system_events
WHERE occurred_at >= current_date - interval '30 days'
GROUP BY 1,2
ORDER BY 1 DESC, 2;

-- 6) Optional materialization for faster dashboards
CREATE MATERIALIZED VIEW IF NOT EXISTS public.mv_metrics_rollup AS
SELECT * FROM public.v_metrics_rollup;

CREATE OR REPLACE FUNCTION public.refresh_mv_metrics_rollup()
RETURNS void LANGUAGE sql AS $$
  refresh materialized view concurrently public.mv_metrics_rollup;
$$;

CREATE INDEX IF NOT EXISTS mv_metrics_rollup_org_date_idx ON public.mv_metrics_rollup (org_id, date desc);

-- 7) Guarded SSO failure view (create only if source table exists; else create empty-compatible view)
DO $$
BEGIN
  IF to_regclass('public.sso_health') IS NOT NULL THEN
    EXECUTE $$
      create or replace view public.v_sso_failure_rate_24h as
      select org_id,
             sum(attempts_24h)::int as attempts_24h,
             sum(failures_24h)::int as failures_24h,
             case when sum(attempts_24h) > 0
                  then sum(failures_24h)::numeric / sum(attempts_24h)
                  else 0 end as failure_rate_24h
      from public.sso_health
      group by org_id;
    $$;
  ELSE
    EXECUTE $$
      create or replace view public.v_sso_failure_rate_24h as
      select cast(null as uuid) as org_id, 0::int as attempts_24h, 0::int as failures_24h, 0::numeric as failure_rate_24h
      where false;
    $$;
  END IF;
END $$;
