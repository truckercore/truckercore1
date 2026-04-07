create or replace view public.v_rls_kpis as
select
  (select 1.0*sum((pass)::int)/greatest(count(*),1) from public.rls_test_results where ran_at>now()-interval '24h') as pass_rate_24h,
  (select count(*) from public.v_rls_lint) as lint_issues,
  (select count(*) from public.v_rls_insert_check_gaps) as insert_check_gaps,
  (select count(*) from public.v_rls_deny_default) as deny_default_tables;
