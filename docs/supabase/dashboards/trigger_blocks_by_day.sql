-- Trigger block counts by day (TRIGGER_BLOCK, CONSTRAINT_BLOCK)
select date_trunc('day', triggered_at) as day,
       code,
       count(*) as blocks
from public.alerts_events
where code in ('TRIGGER_BLOCK','CONSTRAINT_BLOCK')
group by 1,2
order by 1,2;