create or replace view v_ai_factor_coverage_7d as
select
  model_key,
  model_version,
  100.0 * sum(case when factors ?& array['distance','price','fuel'] then 1 else 0 end)
    / nullif(count(*), 0) as pct_with_required
from ai_rank_factors
where created_at > now() - interval '7 days'
group by 1,2;
