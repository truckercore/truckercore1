-- KPI RPC for Fleet Manager dashboard
-- Returns compact KPIs for current org with date-range aggregation:
-- active_trucks (recent pings), deliveries_in_range, on_time_rate_in_range, km_in_range
create or replace function public.fn_dashboard_kpis(
  p_start_date date default current_date,
  p_end_date date default current_date
)
returns table(
  active_trucks int,
  deliveries int,
  on_time_rate numeric,
  km numeric,
  deliveries_prior int,
  on_time_rate_prior numeric,
  km_prior numeric
)
language plpgsql
stable
security definer
as $$
declare
  v_org uuid;
begin
  v_org := coalesce(public.current_org_id(), ((select auth.jwt()) ->> 'org_id')::uuid);
  if v_org is null then
    -- Anonymous; return zeros
    return query select 0::int, 0::int, 0::numeric, 0::numeric;
    return;
  end if;

  return query
  with rng as (
    select greatest(p_start_date, '2000-01-01'::date) as d1,
           least(p_end_date, current_date) as d2
  ),
  trucks as (
    -- recent pings window: last 5 minutes to match "Active Trucks (last 5min ping)"
    select count(*)::int as c
    from public.trucks t
    where t.carrier_id = v_org
      and exists (
        select 1 from public.truck_current_positions cp
        where cp.truck_id = t.id and cp.gps_ts > now() - interval '5 minutes'
      )
  ),
  rng_len as (
    select (d2 - d1 + 1) as days from rng
  ),
  prior_rng as (
    select (select d1 from rng) - (select days from rng_len) as d1p,
           (select d1 from rng) - 1 as d2p
  ),
  agg as (
    -- Aggregate over mv_daily_org_stats across the selected date range
    select
      coalesce(sum(s.deliveries),0) as deliveries,
      coalesce(sum(s.on_time_deliveries),0) as on_time_deliveries,
      coalesce(sum(s.km_traveled),0) as km
    from public.mv_daily_org_stats s, rng
    where s.org_id = v_org
      and s.day >= rng.d1 and s.day <= rng.d2
  ),
  agg_prior as (
    select
      coalesce(sum(s.deliveries),0) as deliveries,
      coalesce(sum(s.on_time_deliveries),0) as on_time_deliveries,
      coalesce(sum(s.km_traveled),0) as km
    from public.mv_daily_org_stats s, prior_rng
    where s.org_id = v_org
      and s.day >= prior_rng.d1p and s.day <= prior_rng.d2p
  )
  select
    coalesce((select c from trucks),0) as active_trucks,
    (select deliveries from agg) as deliveries,
    case when (select deliveries from agg) = 0 then 0
         else round(((select on_time_deliveries from agg))::numeric / nullif((select deliveries from agg),0), 3)
    end as on_time_rate,
    (select km from agg) as km,
    (select deliveries from agg_prior) as deliveries_prior,
    case when (select deliveries from agg_prior) = 0 then 0
         else round(((select on_time_deliveries from agg_prior))::numeric / nullif((select deliveries from agg_prior),0), 3)
    end as on_time_rate_prior,
    (select km from agg_prior) as km_prior;
end;
$$;

revoke all on function public.fn_dashboard_kpis(date, date) from public;
grant execute on function public.fn_dashboard_kpis(date, date) to authenticated;