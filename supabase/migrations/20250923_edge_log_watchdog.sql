-- 20250923_edge_log_watchdog.sql
-- Purpose: Nightly watchdog view for edge_request_log retention and partition readiness.
-- Safe to re-run; uses CREATE OR REPLACE.

create or replace view public.edge_log_watchdog as
with
  oldest as (
    select coalesce(min(ts), now()) as min_ts
    from public.edge_request_log
  ),
  beyond as (
    select count(*) as rows_beyond_30d
    from public.edge_request_log
    where ts < now() - interval '30 days'
  ),
  next_part as (
    select to_char(date_trunc('month', now()) + interval '1 month','YYYY_MM') as next_tag
  ),
  parts as (
    select regexp_replace(inhrelid::regclass::text, '.*_(\d{4}_\d{2})$', '\1') as tag
    from pg_inherits
    where inhparent = 'public.edge_request_log'::regclass
  )
select
  (select rows_beyond_30d from beyond) = 0                                          as retention_ok,
  (select min_ts from oldest) >= now() - interval '30 days'                         as oldest_within_30d,
  exists (select 1 from parts p join next_part n on p.tag = n.next_tag)             as next_partition_present,
  (select rows_beyond_30d from beyond)                                              as rows_beyond_30d,
  (select min_ts from oldest)                                                       as oldest_row_ts;
