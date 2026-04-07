-- docs/supabase/edge_log_verification.sql
-- One-shot verification script for edge_request_log retention and partitions.
-- Run with Supabase CLI (linked project):
--   supabase db query docs/supabase/edge_log_verification.sql
-- Or via Makefile:
--   make db-verify-edge-logs

-- 1) Retention sanity (should be ≤ 30 days)
\echo 'A) Retention sanity (oldest/newest/rows)'
select min(ts) as oldest, max(ts) as newest, count(*) as rows
from public.edge_request_log;

-- 1.B) Verification view (ensure it returns what you expect)
\echo 'B) edge_log_stats_24h view'
select * from public.edge_log_stats_24h;

-- 1.C) Partition presence (if partitioning is enabled on edge_request_log)
\echo 'C) Partition presence and sizes'
select inhrelid::regclass as partition,
       pg_size_pretty(pg_total_relation_size(inhrelid)) as size
from pg_inherits
where inhparent = 'public.edge_request_log'::regclass
order by partition;

-- 1.D) Partition pruning in query plan (look for "Partition pruning:")
\echo 'D) EXPLAIN ANALYZE with month filter (inspect for Partition pruning)'
explain analyze
select count(*)
from public.edge_request_log
where ts >= date_trunc('month', now());

-- 2) Weekly partition auto-create proof -------------------------------------
\echo '2) Ensuring next month partition exists (runs weekly in prod)'
select public.ensure_next_month_edge_log_partition();

\echo '2.b) Confirm indexes exist on next-month partition'
select c.relname as idx, pg_get_indexdef(i.indexrelid)
from pg_index i
join pg_class c on c.oid = i.indexrelid
where i.indrelid = format(
  'public.edge_request_log_%s',
  to_char(date_trunc('month', now()) + interval '1 month','YYYY_MM')
)::regclass;

-- 3) Retention actually prunes ----------------------------------------------
-- Insert a canary older than 30 days, prune, and verify it's gone.
\echo '3) Inserting 45-day-old canary row'
insert into public.edge_request_log (op, ts, ok, ms)
values ('canary', now() - interval '45 days', true, 1);

\echo '3.b) Trigger prune_edge_logs()'
select public.prune_edge_logs();

\echo '3.c) Expect 0 canaries after prune'
select count(*) as canaries
from public.edge_request_log where op = 'canary';

-- Scheduling hints (hands-off in prod):
-- - Nightly prune:                 0 3 * * *
-- - Weekly partition ensure:       0 4 * * 0
-- - (Optional) Nightly VACUUM after prune: VACUUM ANALYZE public.edge_request_log;

-- Drift guard (alert if > 0)
\echo 'Drift guard: rows older than 30 days (should be 0 after prune)'
select count(*) as beyond_30d
from public.edge_request_log
where ts < now() - interval '30 days';

-- Visibility tile (pin in Studio)
\echo 'Visibility tile: oldest/newest and rows_beyond_retention'
select 
  (select min(ts) from public.edge_request_log) as oldest,
  (select max(ts) from public.edge_request_log) as newest,
  (select count(*) from public.edge_request_log where ts < now() - interval '30 days') as rows_beyond_retention;
