-- docs/sql/kpis_weekly_helpers.sql
-- first_seen / last_seen / occurrences per code (7d)
create or replace view public.v_alert_bounds_7d as
with windowed as (
  select org_id, code, severity, triggered_at
  from public.alerts_events
  where triggered_at >= now() - interval '7 days'
),
bounds as (
  select org_id, code, min(triggered_at) as first_seen, max(triggered_at) as last_seen, count(*) as occurrences
  from windowed group by org_id, code
),
sev_latest as (
  select distinct on (org_id, code) org_id, code, severity, triggered_at
  from windowed order by org_id, code, triggered_at desc
)
select b.org_id, b.code, b.first_seen, b.last_seen, b.occurrences, sl.severity as last_severity
from bounds b left join sev_latest sl using (org_id, code);
