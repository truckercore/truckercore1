begin;

create or replace view v_ai_roi_spike_seasonal as
with daily as (
  select org_id, date_trunc('day', created_at) d,
         extract(dow from created_at)::int dow, sum(amount_cents) amt
  from ai_roi_events
  where created_at >= now()-interval '35 days'
  group by 1,2,3
),
ref as (
  select org_id, dow,
         percentile_cont(0.5) within group (order by amt) as med_dow
  from daily
  where d < date_trunc('day', now())
  group by org_id, dow
),
today as (
  select org_id, extract(dow from now())::int as dow_today,
         sum(amt) as amt_today
  from daily where d = date_trunc('day', now())
  group by org_id
)
select t.org_id, t.amt_today, r.med_dow,
       case when r.med_dow=0 then null else t.amt_today / r.med_dow end as multiple,
       now() as computed_at
from today t
join ref r on r.org_id=t.org_id and r.dow=t.dow_today
where r.med_dow > 0 and t.amt_today > 3 * r.med_dow;

grant select on v_ai_roi_spike_seasonal to authenticated, anon;

commit;
