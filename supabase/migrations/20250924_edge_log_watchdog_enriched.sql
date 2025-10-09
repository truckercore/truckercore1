-- 20250924_edge_log_watchdog_enriched.sql
-- Purpose: Enrich edge_log_watchdog with drift signals (noisy → calm) and maintenance context.
-- Safe to re-run; CREATE OR REPLACE VIEW only.

create or replace view public.edge_log_watchdog as
with
  oldest as (select min(ts) as min_ts from public.edge_request_log),
  beyond as (
    select count(*) as rows_beyond_30d
    from public.edge_request_log
    where ts < now() - interval '30 days'
  ),
  next_part as (select to_char(date_trunc('month', now()) + interval '1 month','YYYY_MM') as next_tag),
  parts as (
    select regexp_replace(inhrelid::regclass::text, '.*_(\d{4}_\d{2})$', '\1') as tag
    from pg_inherits
    where inhparent = 'public.edge_request_log'::regclass
  ),
  maint as (
    select max(ran_at) as last_maint_at, bool_or(ok) as last_ok
    from public.ops_maintenance_log
    where task = 'nightly_maintenance'
  ),
  -- drift signals: compare last 7d vs prior 7d for insert volume and error ratio
  vol as (
    select
      sum(case when ts >= now() - interval '7 days' then 1 else 0 end)::numeric as v7,
      sum(case when ts <  now() - interval '7 days'
                and ts >= now() - interval '14 days' then 1 else 0 end)::numeric as vprev7,
      sum(case when ts >= now() - interval '7 days' and status >= 500 then 1 else 0 end)::numeric as e7,
      sum(case when ts <  now() - interval '7 days'
                and ts >= now() - interval '14 days' and status >= 500 then 1 else 0 end)::numeric as eprev7
    from public.edge_request_log
  )
select
  (select rows_beyond_30d from beyond) = 0                                  as retention_ok,
  coalesce((select min_ts from oldest) >= now() - interval '30 days', true)  as oldest_within_30d,
  exists (select 1 from parts p join next_part n on p.tag = n.next_tag)      as next_partition_present,
  (select rows_beyond_30d from beyond)                                       as rows_beyond_30d,
  (select min_ts from oldest)                                                as oldest_row_ts,
  (select last_maint_at from maint)                                          as last_maintenance_at,
  (select last_ok from maint)                                                as last_maintenance_ok,
  now() - (select last_maint_at from maint)                                  as maintenance_lag,
  -- drift signals
  case
    when (select v7 from vol) = 0 or (select vprev7 from vol) = 0 then 'calm'
    when (select (e7/nullif(v7,0)) from vol) - (select (eprev7/nullif(vprev7,0)) from vol) > 0.02 then 'noisy'
    when (select v7 from vol) > (select vprev7 from vol) * 1.5 then 'noisy'
    else 'calm'
  end as drift_signal,
  (select (e7/nullif(v7,0)) from vol)                                        as error_rate_7d,
  (select (eprev7/nullif(vprev7,0)) from vol)                                as error_rate_prev7,
  (select v7 from vol)                                                       as volume_7d,
  (select vprev7 from vol)                                                   as volume_prev7
;
