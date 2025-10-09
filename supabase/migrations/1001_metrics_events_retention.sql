-- 1001_metrics_events_retention.sql
-- Purpose: add fast indexes for metrics_events and a simple retention helper (90 days default).
-- This migration is idempotent.

-- 1) Indexes for common analytics queries
--    Fast lookups by kind and time range
create index if not exists metrics_events_kind_idx on public.metrics_events(kind);
create index if not exists metrics_events_created_at_idx on public.metrics_events(created_at desc);

-- 2) Retention helper (simple delete; consider partitioning for very large tables)
create or replace function public.purge_metrics_events(p_days int default 90)
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.metrics_events
  where created_at < now() - (p_days || ' days')::interval;
$$;

-- 3) (Optional) If pg_cron is available, you can schedule the daily purge like this:
-- select cron.schedule('metrics_events_retention_daily',
--   '15 3 * * *',
--   $$select public.purge_metrics_events(90);$$
-- );

-- If pg_cron isn't available, schedule via Supabase Scheduled Task or your CI/CD.
