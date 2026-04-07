-- 995_ops_alert_health_views.sql
-- Alert health views (ops at a glance)

-- Pending by key + oldest age
create or replace view public.ops_alerts_backlog as
select
  key,
  count(*) filter (where delivered_at is null) as pending,
  min(created_at) filter (where delivered_at is null) as oldest_pending
from public.alert_outbox
group by key
order by pending desc;

-- Dedupe efficiency: how many duplicates suppressed in the last 24h
create or replace view public.ops_alert_dedupe_24h as
with base as (
  select dedupe_key, count(*) as total
  from public.alert_outbox
  where created_at >= now() - interval '24 hours'
  group by dedupe_key
)
select sum(greatest(total - 1, 0)) as suppressed_duplicates
from base;
