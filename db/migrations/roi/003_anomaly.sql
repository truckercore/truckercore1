begin;

create or replace view v_roi_anomalies as
with x as (
  select
    event_type,
    amount_cents,
    created_at,
    percentile_cont(0.5) within group (order by amount_cents) over (partition by event_type) as med,
    percentile_cont(0.5) within group (order by abs(amount_cents)) over (partition by event_type) as mad_raw
  from ai_roi_events
  where created_at >= now() - interval '30 days'
),
 y as (
  select
    event_type,
    amount_cents,
    created_at,
    med,
    nullif(mad_raw, 0) as mad,
    abs(amount_cents - med) / greatest(nullif(mad_raw, 0), 1) as mad_score
  from x
)
select *
from y
where mad_score > 10;

grant select on v_roi_anomalies to authenticated, anon;

commit;
