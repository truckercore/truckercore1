-- 20250924_incidents_freshness_view.sql
-- Quiet alerting: freshness watchdog for incidents. Idempotent.

create or replace view public.incidents_freshness as
select 'incidents' as key,
       now() - max(observed_at) as lag
from public.traffic_incidents;