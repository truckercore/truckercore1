create or replace function risk_aggregate_for_lane(p_from text, p_to text, p_equip text)
returns table(n_trips int, avg_speed numeric, speed_std numeric, cancel_rate numeric)
language sql as $$
  with trips as (
    select fe.load_id,
           avg(ft.speed_mph) as avg_speed,
           stddev_samp(ft.speed_mph) as sd_speed
    from fact_load_events fe
    join fact_telemetry_snap ft on ft.org_id = fe.org_id
    where fe.lane_from=p_from and fe.lane_to=p_to and fe.equipment=p_equip
      and fe.event_type in ('pickup','delivered')
      and ft.ts between fe.created_at - interval '1 day' and fe.created_at + interval '10 days'
    group by fe.load_id
  ),
  canc as (
    select count(*) filter (where event_type='cancelled')::numeric /
           nullif(count(*) filter (where event_type in ('posted','matched')),0) as cancel_rate
    from fact_load_events where lane_from=p_from and lane_to=p_to and equipment=p_equip
  )
  select count(*) as n_trips,
         avg(avg_speed) as avg_speed,
         avg(sd_speed)  as speed_std,
         (select cancel_rate from canc) as cancel_rate
  from trips;
$$;