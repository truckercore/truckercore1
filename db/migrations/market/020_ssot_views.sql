begin;

create or replace view v_lane_performance_day as
with loads as (
  select date_trunc('day', created_at) d, lane_from, lane_to, equipment,
         count(*) filter (where event_type='posted') as posted,
         count(*) filter (where event_type='matched') as matched
  from fact_load_events
  where created_at > now() - interval '90 days'
  group by 1,2,3,4
),
rates as (
  select date_trunc('day', observed_at) d, lane_from, lane_to, equipment,
         percentile_cont(0.5) within group (order by accepted_rate_usd) as p50_rate
  from fact_pricing
  where observed_at > now() - interval '90 days'
  group by 1,2,3,4
)
select l.d, l.lane_from, l.lane_to, l.equipment,
       (l.matched::numeric / nullif(l.posted,0)) as fill_rate,
       r.p50_rate
from loads l
left join rates r using (d, lane_from, lane_to, equipment);

create or replace view v_industry_benchmarks_7d as
select lane_from, lane_to, equipment,
       count(*) as n,
       percentile_cont(0.5) within group (order by accepted_rate_usd) as p50_rate_7d,
       percentile_cont(0.9) within group (order by accepted_rate_usd) as p90_rate_7d
from fact_pricing
where observed_at > now() - interval '7 days'
group by 1,2,3;

commit;
