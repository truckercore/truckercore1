-- docs/sql/sso_canary.sql
create table if not exists public.sso_canary_results(
  id bigserial primary key,
  at timestamptz not null default now(),
  idp text not null,
  tenant uuid not null,
  ok boolean not null,
  latency_ms int,
  err text
);

create or replace view public.v_sso_canary_24h as
select idp,
       tenant,
       count(*)                                                        as runs,
       sum((not ok)::int)::float / greatest(count(*), 1)               as fail_rate,
       percentile_disc(0.95) within group (order by latency_ms)        as p95_ms
from public.sso_canary_results
where at > now() - interval '24 hours'
group by idp, tenant;
