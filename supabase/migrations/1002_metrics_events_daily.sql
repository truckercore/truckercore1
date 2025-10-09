-- 1002_metrics_events_daily.sql
-- Daily counts by kind for quick health checks + top kinds 24h and optional p95 latency.

-- Use a resilient timestamp that works whether your table uses created_at or at
create or replace view public.metrics_events_daily as
select
  date_trunc('day', coalesce(created_at, at)) as day,
  coalesce(kind, event_code, 'unknown') as kind,
  count(*) as events
from public.metrics_events
where coalesce(created_at, at) >= now() - interval '30 days'
group by 1, 2
order by 1 desc, 2;

create or replace view public.metrics_events_top_24h as
select coalesce(kind, event_code, 'unknown') as kind, count(*) as events_24h
from public.metrics_events
where coalesce(created_at, at) >= now() - interval '24 hours'
group by 1
order by events_24h desc;

-- Optional p95 latency by kind in last 24h if ms is logged in JSON states
-- Looks for a numeric field named "ms" in either new_state or prev_state
create or replace view public.metrics_events_p95_24h as
with vals as (
  select
    coalesce(kind, event_code, 'unknown') as kind,
    nullif(coalesce(
      (new_state ->> 'ms')::numeric,
      (prev_state ->> 'ms')::numeric
    ), 0) as ms
  from public.metrics_events
  where coalesce(created_at, at) >= now() - interval '24 hours'
)
select kind,
       percentile_disc(0.95) within group (order by ms) as p95_ms,
       percentile_disc(0.50) within group (order by ms) as p50_ms,
       count(*) filter (where ms is not null) as samples
from vals
where ms is not null
group by kind
order by p95_ms desc nulls last;