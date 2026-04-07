begin;
grant select on ai_health to anon, authenticated;
comment on view ai_health is 'Aggregated, non-PII AI health metrics for dashboards and CI gates.';
commit;
