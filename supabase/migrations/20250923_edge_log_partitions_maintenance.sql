-- 20250923_edge_log_partitions_maintenance.sql
-- Purpose: Ensure ≤30d retention, partition maintenance helpers, parent partitioned indexes,
--          and a 24h stats view for edge_request_log.
-- Safe to re-run. Uses CREATE OR REPLACE and IF NOT EXISTS guards.

-- Defensive migration guards
set statement_timeout = '2min';
set lock_timeout = '10s';
begin;

-- 1) Verification helpers are in docs/issue; this migration adds DB objects supporting them.

-- 1.a) Function: auto-create next month's partition (run weekly via scheduler)
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

      -- Per-partition indexes (mirror common query patterns)
      execute format('create index if not exists %I_ts_idx on public.%I (ts desc)', part_name, part_name);
      execute format('create index if not exists %I_op_ts_ms_idx on public.%I (op, ts desc, ms)', part_name, part_name);
      execute format('create index if not exists %I_org_ts_idx on public.%I (org_id, ts desc)', part_name, part_name);
    end if;
  end if;
end;
$$;

-- 1.b) Parent partitioned indexes (apply to future partitions automatically)
create index if not exists edge_request_log_pidx_ts
  on public.edge_request_log using btree (ts desc);
create index if not exists edge_request_log_pidx_op_ts_ms
  on public.edge_request_log using btree (op, ts desc, ms);
create index if not exists edge_request_log_pidx_org_ts
  on public.edge_request_log using btree (org_id, ts desc);

-- 1.c) Retention sanity view (24h rows; beyond 30d rows should be 0 after prune)
create or replace view public.edge_log_stats_24h as
select
  (select count(*) from public.edge_request_log where ts >= now() - interval '24 hours') as rows_24h,
  (select count(*) from public.edge_request_log where ts <  now() - interval '30 days') as rows_beyond_retention;

commit;
reset statement_timeout;
reset lock_timeout;

-- Note: Scheduling hints (set up via Supabase Scheduled Triggers):
-- - Prune nightly: call public.prune_edge_logs() at 03:00 local (e.g., 0 3 * * * project time)
-- - Ensure next partition weekly: call select public.ensure_next_month_edge_log_partition(); at 04:00 Sundays (0 4 * * 0)
