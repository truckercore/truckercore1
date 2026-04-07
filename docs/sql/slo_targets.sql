create table if not exists slo_targets(
  fn text primary key, p95_ms int not null, budget_error_rate numeric not null default 0.005
);

create or replace view v_slo_burn as
select i.fn, t.p95_ms, t.budget_error_rate,
  percentile_disc(0.95) within group (order by i.ms) as p95_obs,
  sum((i.status='error')::int)::numeric / greatest(count(*),1) as err_rate
from function_invocations i
join slo_targets t using(fn)
where i.at > now() - interval '1 day'
group by i.fn, t.p95_ms, t.budget_error_rate;
