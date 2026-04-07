-- 20250923_edge_request_log_retention.sql
-- Purpose: Retention + optional monthly partitioning for edge_request_log, plus tight indexes.
-- Safe to re-run; uses IF EXISTS/IF NOT EXISTS and guarded DO blocks.

-- Defensive migration guards
set statement_timeout = '2min';
set lock_timeout = '10s';
begin;

-- 1) Retention function (30-day prune), scheduled nightly via Supabase scheduler or external cron
create or replace function public.prune_edge_logs()
returns void
language plpgsql
security definer
as $$
begin
  delete from public.edge_request_log
  where ts < now() - interval '30 days';
end
$$;

revoke all on function public.prune_edge_logs() from public;
grant execute on function public.prune_edge_logs() to service_role;

-- 2) Optional: convert to monthly partitions by range(ts) (Postgres 14+)
-- Only attempt if table is not already partitioned. If conversion fails (e.g., table non-empty), ignore.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_partitioned_table pt
    JOIN pg_class c ON c.oid = pt.partrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relname = 'edge_request_log'
  ) THEN
    BEGIN
      EXECUTE 'alter table public.edge_request_log partition by range (ts)';
    EXCEPTION WHEN others THEN
      -- Optional conversion; skip if not possible
      NULL;
    END;
  END IF;
END$$;

-- Create current month partition only if parent is partitioned
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_partitioned_table pt
    JOIN pg_class c ON c.oid = pt.partrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relname = 'edge_request_log'
  ) THEN
    -- Adjust month boundaries as needed in a scheduler; here we create 2025-09 partition
    IF NOT EXISTS (
      SELECT 1 FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public' AND c.relname = 'edge_request_log_2025_09'
    ) THEN
      EXECUTE $$create table public.edge_request_log_2025_09
        partition of public.edge_request_log
        for values from ('2025-09-01') to ('2025-10-01')$$;
    END IF;
  END IF;
END$$;

-- 3) Tight indexes for top queries
-- Note: On a partitioned table, creating an index on the parent creates a partitioned index
-- that will apply to future partitions. Existing partitions may need separate indexes if created earlier.
create index if not exists edge_request_log_ts_idx
  on public.edge_request_log (ts desc);

create index if not exists edge_request_log_op_ms_idx
  on public.edge_request_log (op, ts desc, ms);

commit;
reset statement_timeout;
reset lock_timeout;
