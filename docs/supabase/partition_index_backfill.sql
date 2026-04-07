-- docs/supabase/partition_index_backfill.sql
-- One-time safety net to ensure existing child partitions have common indexes
-- when a parent partitioned index was introduced after some partitions already existed.
-- Safe to run multiple times (IF NOT EXISTS per child/index).
--
-- Applies to public.edge_request_log children:
--   - ts DESC
--   - (op, ts DESC, ms)
--   - (org_id, ts DESC)
--   - status
--
-- Usage (Supabase SQL editor or CLI):
--   supabase db query docs/supabase/partition_index_backfill.sql

DO $$
DECLARE
  r record;
  child regclass;
  part_name text;
BEGIN
  FOR r IN (
    select inhrelid::regclass as child
    from pg_inherits
    where inhparent = 'public.edge_request_log'::regclass
  ) LOOP
    child := r.child;
    part_name := split_part(child::text, '.', 2);

    -- ts desc
    EXECUTE format('create index if not exists %I_ts_idx on %s (ts desc)', part_name, child::text);
    -- op, ts desc, ms
    EXECUTE format('create index if not exists %I_op_ts_ms_idx on %s (op, ts desc, ms)', part_name, child::text);
    -- org_id, ts desc
    EXECUTE format('create index if not exists %I_org_ts_idx on %s (org_id, ts desc)', part_name, child::text);
    -- status
    EXECUTE format('create index if not exists %I_status_idx on %s (status)', part_name, child::text);
  END LOOP;
END $$;