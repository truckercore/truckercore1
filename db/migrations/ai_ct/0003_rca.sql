begin;

create or replace function ai_eta_rca(minutes_back int)
returns table (
  cohort text,
  n int,
  mae_min numeric,
  dist_km_mean numeric,
  speed_mean numeric,
  hour_mean numeric
)
language sql stable as $$
  with joined as (
    select
      (i.features->>'distance_km')::numeric as dist,
      (i.features->>'avg_speed_hist')::numeric as spd,
      (i.features->>'hour_of_day')::int as hr,
      abs((i.prediction->>'eta_min')::numeric - (f.actual->>'eta_min')::numeric) as ae
    from ai_inference_events i
    join ai_feedback_events f using (correlation_id)
    where i.model_key = 'eta'
      and i.created_at >= now() - make_interval(mins => minutes_back)
  ),
  buckets as (
    select
      case
        when dist > 400 then 'long-haul'
        when dist > 100 then 'mid-haul'
        else 'short-haul'
      end as cohort,
      dist, spd, hr, ae
    from joined
  )
  select
    cohort,
    count(*)::int as n,
    avg(ae) as mae_min,
    avg(dist) as dist_km_mean,
    avg(spd) as speed_mean,
    avg(hr) as hour_mean
  from buckets
  group by cohort
  order by 3 desc;
$$;

grant execute on function ai_eta_rca(int) to service_role, authenticated;

commit;
