-- docs/sql/kpis_entitlements.sql
create or replace view public.v_entitlement_denials_7d as
select reason_code, count(*) as hits
from public.entitlement_error_events
where at > now() - interval '7 days'
group by reason_code
order by hits desc;
