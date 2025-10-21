# Function Metrics and RLS Denials (Observability)

This migration adds two tables, one helper function, and two views to support quick health checks and SLO dashboards for RPCs/Edge Functions.

What it creates
- Tables
  - public.fn_metrics: per-call metrics (fn_name, status, duration_ms, ctx, user/org, optional error fields)
  - public.rls_denials: optional audit log for access denials
- Function
  - public.log_fn_metric(name text, status text, duration_ms integer, ctx jsonb, err_code text default null, err_text text default null)
    - SECURITY DEFINER; stamps auth.uid() and org_id claim.
- Views (24h)
  - public.v_fn_p95_24h: p95 latency by function (status = 'ok')
  - public.v_fn_status_24h: status counts by function

Apply
```sql
\i docs/supabase/observability_fn_metrics.sql
```

Verify in order
- Tables
  - select to_regclass('public.fn_metrics'), to_regclass('public.rls_denials');
- Insert a test metric
  - select public.log_fn_metric('smoke','ok',12,'{}'::jsonb);
  - select * from public.fn_metrics order by created_at desc limit 1;
- Views
  - select * from public.v_fn_p95_24h;
  - select * from public.v_fn_status_24h;

Tip
- If you run migrations inside a single transaction, avoid CREATE INDEX CONCURRENTLY. The statements in the SQL file are transaction‑safe.
