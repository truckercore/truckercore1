-- docs/sql/observability.sql
create table if not exists public.function_invocations (
  id bigserial primary key,
  at timestamptz not null default now(),
  fn text not null,
  status text not null check (status in ('ok','error')),
  ms int not null,
  org_id uuid null,
  request_id text null
);
create index if not exists idx_fn_slo_time on public.function_invocations (fn, at desc);

create or replace view public.function_slo_last_24h as
select fn,
       count(*) as calls,
       percentile_disc(0.95) within group (order by ms) as p95_ms,
       sum((status='error')::int)::float / greatest(count(*),1) as error_rate
from public.function_invocations
where at > now() - interval '24 hours'
group by fn;
