-- 20250923_edge_opslog.sql
-- Edge ops request logging + 24h SLO view (idempotent)
-- Safe to re-run.

create table if not exists public.edge_request_log (
  id bigserial primary key,
  ts timestamptz not null default now(),
  op text not null,
  org_id uuid,
  trace_id text,
  ok boolean not null,
  ms integer not null,
  status int,
  err text
);

create index if not exists edge_request_log_op_ts_idx on public.edge_request_log (op, ts desc);
create index if not exists edge_request_log_org_ts_idx on public.edge_request_log (org_id, ts desc);

-- Read-only SLO view for last 24h
create or replace view public.edge_op_slo_24h as
with base as (
  select op,
         count(*) as calls,
         count(*) filter (where not ok) as errors,
         percentile_cont(0.95) within group (order by ms) as p95_ms
  from public.edge_request_log
  where ts >= now() - interval '24 hours'
  group by op
)
select op,
       calls,
       errors,
       (errors::decimal / nullif(calls,0)) as error_rate,
       p95_ms
from base
order by error_rate desc nulls last, p95_ms desc;