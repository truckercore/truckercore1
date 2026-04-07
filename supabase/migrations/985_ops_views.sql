create or replace view public.ops_fn_errors_24h as
select date_trunc('hour', created_at) as hour, fn, count(*) as errors
from public.function_audit_log
where success = false and created_at >= now() - interval '24 hours'
group by 1,2
order by 1 desc;

create or replace view public.ops_alerts_pending as
select key, count(*) as pending, min(created_at) as oldest
from public.alert_outbox
where delivered_at is null
group by 1
order by pending desc;

create or replace view public.ops_rollup_status as
select o.id as org_id, o.name,
  (select max(date) from public.org_metrics_daily d where d.org_id=o.id) as latest_metric_date
from public.orgs o;

create or replace view public.ops_table_sizes as
select relname as table, pg_total_relation_size(relid) as bytes
from pg_catalog.pg_statio_user_tables
order by bytes desc;
