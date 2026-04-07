-- Evidence views (executive + SOC2)

create or replace view public.v_usage_kpis as
select
  (select sum(total_units) from public.usage_monthly where period >= date_trunc('month', now())) as units_mtd,
  (select count(distinct org_id) from public.usage_monthly where period >= date_trunc('month', now())) as active_orgs_mtd,
  (select count(*) from public.v_usage_sync_drift) as sync_drift_open,
  (select count(*) from public.v_usage_anomaly)    as anomalies_open;
