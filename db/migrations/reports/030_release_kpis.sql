begin;
create or replace view v_release_kpis as
select
  now() as generated_at,
  (select coalesce(min(pct_with_required),100) from v_ai_factor_coverage_7d) as min_factor_cov_7d;
commit;
