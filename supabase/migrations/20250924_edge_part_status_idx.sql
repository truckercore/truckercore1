-- 20250924_edge_part_status_idx.sql
-- Purpose: Extend partition maintenance to include status index on edge_request_log partitions
--          and add parent partitioned status index. Safe to re-run.

set statement_timeout = '2min';
set lock_timeout = '10s';
begin;

-- Parent partitioned index for status so future partitions inherit it (Postgres 14+)
create index if not exists edge_request_log_pidx_status
  on public.edge_request_log using btree (status);

-- Replace ensure_next_month_edge_log_partition() to also create a per-partition status index
create or replace function public.ensure_next_month_edge_log_partition()
returns void language plpgsql as $$
declare
  start_of_next date := (date_trunc('month', now()) + interval '1 month')::date;
  end_of_next   date := (date_trunc('month', now()) + interval '2 month')::date;
  part_name     text := format('edge_request_log_%s', to_char(start_of_next, 'YYYY_MM'));
  stmt          text;
begin
  -- Only proceed if parent table is partitioned
  if exists (
    select 1
    from pg_partitioned_table pt
    join pg_class c on c.oid = pt.partrelid
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'edge_request_log'
  ) then
    if not exists (
      select 1 from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public' and c.relname = part_name
    ) then
      stmt := format($f$
        create table public.%I
        partition of public.edge_request_log
        for values from (%L) to (%L);
      $f$, part_name, start_of_next::timestamp, end_of_next::timestamp);
      execute stmt;
    end if;

    -- Ensure common per-partition indexes exist (ts, op+ts+ms, org+ts, status)
    execute format('create index if not exists %I_ts_idx on public.%I (ts desc)', part_name, part_name);
    execute format('create index if not exists %I_op_ts_ms_idx on public.%I (op, ts desc, ms)', part_name, part_name);
    execute format('create index if not exists %I_org_ts_idx on public.%I (org_id, ts desc)', part_name, part_name);
    execute format('create index if not exists %I_status_idx on public.%I (status)', part_name, part_name);
  end if;
end;
$$;

-- Optional: backfill status indexes on existing partitions
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN (
    select inhrelid::regclass as part
    from pg_inherits
    where inhparent = 'public.edge_request_log'::regclass
  ) LOOP
    EXECUTE format('create index if not exists %I_status_idx on %s (status)',
                   split_part(r.part::text, '.', 2), r.part::text);
  END LOOP;
END $$;

commit;
reset statement_timeout;
reset lock_timeout;
