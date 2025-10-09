-- supabase/remediation/commands.sql
-- Prune retention breach
select public.prune_edge_logs();
vacuum analyze public.edge_request_log;

-- Ensure partition exists
select public.ensure_next_month_edge_log_partition();
