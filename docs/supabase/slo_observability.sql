-- SLO Observability schema (v1)
-- Tables and views to support slo_emit EF and dashboard queries

create table if not exists public.slo_events (
  id bigserial primary key,
  org_id uuid,
  route text not null,
  latency_ms integer not null check (latency_ms >= 0),
  ok boolean not null,
  trace_id text,
  created_at timestamptz not null default now()
);
create index if not exists idx_slo_route_time on public.slo_events(route, created_at desc);
create index if not exists idx_slo_org_time on public.slo_events(org_id, created_at desc);

-- Last 24h SLO rollup with p95 per route
create or replace view public.v_slo_last24 as
select
  route,
  count(*) as n,
  avg(latency_ms)::int as avg_ms,
  percentile_cont(0.95) within group (order by latency_ms) as p95_ms,
  sum(case when ok then 1 else 0 end)::int as ok_count,
  sum(case when not ok then 1 else 0 end)::int as error_count,
  min(created_at) as first_at,
  max(created_at) as last_at
from public.slo_events
where created_at > now() - interval '24 hours'
group by route
order by route;
