-- docs/supabase/pilot_kpi_views.sql
-- Materialized/standard views for Pilot KPI Dashboard. Idempotent.
-- Note: Replace source table names as needed to match your deployment.

-- Helper date range parameters: use CURRENT_DATE - interval in client queries.

-- 1) Fuel uplift summary (value + % vs baseline)
create or replace view public.kpi_fuel_uplift_summary as
with before as (
  select org_id, sum(gallons) as gal
  from public.gallons_daily_baseline -- expected pre-pilot baseline daily gallons per org/location
  where day >= current_date - interval '30 days'
  group by org_id
), after as (
  select org_id, sum(gallons) as gal
  from public.gallons_daily -- measured gallons per day
  where day >= current_date - interval '30 days'
  group by org_id
)
select coalesce(a.org_id, b.org_id) as org_id,
       coalesce(a.gal,0) as gallons,
       case when b.gal is null or b.gal = 0 then null else (coalesce(a.gal,0) - b.gal) / nullif(b.gal,0) end as pct_delta
from after a
full outer join before b on a.org_id = b.org_id;

-- 2) Promo redemptions summary (approved count and conversion rate scan->approve)
create or replace view public.kpi_promo_redemptions_summary as
with scans as (
  select org_id, count(*) as scans
  from public.promo_scans
  where ts >= now() - interval '30 days'
  group by org_id
), approvals as (
  select org_id, count(*) as approvals
  from public.promo_redemptions
  where status = 'approved' and ts >= now() - interval '30 days'
  group by org_id
)
select coalesce(s.org_id, a.org_id) as org_id,
       coalesce(a.approvals,0) as approvals,
       case when coalesce(s.scans,0)=0 then null else coalesce(a.approvals,0)::numeric / nullif(s.scans,0) end as conversion_rate
from scans s full outer join approvals a on s.org_id = a.org_id;

-- 3) Parking freshness (% hours with update < 30 min)
create or replace view public.kpi_parking_freshness as
with hrs as (
  select org_id, date_trunc('hour', ts) as hour, max(ts) as last_update
  from public.parking_state_events -- event log of parking updates per org/location
  where ts >= now() - interval '30 days'
  group by org_id, date_trunc('hour', ts)
)
select org_id,
       avg(case when now() - last_update <= interval '30 minutes' then 1.0 else 0.0 end) as pct_fresh
from hrs
group by org_id;

-- 4) Uptime summary for pilot components
create or replace view public.kpi_uptime_summary as
with win as (
  select generate_series(now() - interval '30 days', now(), interval '5 minutes') as ts
), svc as (
  select service, ts, status
  from public.uptime_health -- columns: service, ts, status in ('up','down','degraded')
  where ts >= now() - interval '30 days'
)
select service,
       avg(case when status = 'up' then 1.0 when status = 'degraded' then 0.5 else 0.0 end) as availability
from svc
group by service;

-- 5) Best stop lift (top location uplift in gallons or in-store sales)
create or replace view public.kpi_best_stop_lift as
with before as (
  select location_id, sum(gallons) as gal
  from public.gallons_daily_baseline
  where day >= current_date - interval '30 days'
  group by location_id
), after as (
  select location_id, sum(gallons) as gal
  from public.gallons_daily
  where day >= current_date - interval '30 days'
  group by location_id
)
select a.location_id,
       (a.gal - coalesce(b.gal,0)) as lift_gallons
from after a left join before b on a.location_id = b.location_id
order by lift_gallons desc
limit 1;

-- 6) Promo funnel
create or replace view public.kpi_promo_funnel as
select coalesce(sum(impressions),0) as impressions,
       coalesce(sum(saves),0) as saves,
       coalesce(sum(scans),0) as scans,
       coalesce(sum(approvals),0) as approvals,
       coalesce(sum(est_gallons),0) as gallons
from public.promo_daily_agg
where day >= current_date - interval '30 days';

-- 7) Top promos
create or replace view public.kpi_top_promos as
select promo_id,
       max(promo_name) as promo_name,
       sum(case when status='approved' then 1 else 0 end) as redemptions,
       avg(approval_prob) as approval_pct,
       sum(est_revenue_uplift) as est_revenue_uplift,
       sum(cost) as cost,
       case when sum(cost)=0 then null else sum(est_revenue_uplift)/nullif(sum(cost),0) end as roi
from public.promo_redemptions_detail
where ts >= now() - interval '30 days'
group by promo_id
order by redemptions desc
limit 20;

-- 8) Fuel competitiveness line
create or replace view public.kpi_fuel_competitiveness as
select day, location_id,
       price_self, price_median_nearby,
       (price_median_nearby - price_self) as advantage
from public.fuel_prices_vs_competitor
where day >= current_date - interval '30 days';

-- 9) Uplift compare
create or replace view public.kpi_uplift_compare as
select day, location_id,
       gallons_before as before_gpd,
       gallons_after as after_gpd
from public.gallons_uplift_compare
where day >= current_date - interval '30 days';

-- 10) Parking heatmap
create or replace view public.kpi_parking_heatmap as
select location_id,
       extract(dow from ts) as dow,
       extract(hour from ts) as hour,
       avg(fill_pct) as avg_fill
from public.parking_fill_observations
where ts >= now() - interval '30 days'
group by location_id, extract(dow from ts), extract(hour from ts);

-- 11) Parking source mix
create or replace view public.kpi_parking_source_mix as
select org_id,
       source,
       avg(confidence) as avg_confidence,
       count(*) as samples
from public.parking_state_events
where ts >= now() - interval '30 days'
group by org_id, source;

-- 12) Dwell time distribution
create or replace view public.kpi_dwell_time as
select org_id,
       case when dwell_minutes <= 20 then 'quick_fuel' else 'park' end as segment,
       percentile_cont(0.5) within group (order by dwell_minutes) as p50,
       percentile_cont(0.9) within group (order by dwell_minutes) as p90
from public.dwell_time_events
where ts >= now() - interval '30 days'
group by org_id, segment;

-- 13) Redeemer segments
create or replace view public.kpi_redeemer_segments as
select org_id, segment, count(*) as redemptions
from public.promo_redeemer_segments
where ts >= now() - interval '30 days'
group by org_id, segment;

-- 14) Uptime timeline
create or replace view public.kpi_uptime_timeline as
select service, ts, status
from public.uptime_health
where ts >= now() - interval '7 days';

-- 15) Incidents list
create or replace view public.kpi_incidents as
select severity, opened_at, closed_at,
       extract(epoch from (first_response_at - opened_at))/60.0 as mtta,
       extract(epoch from (coalesce(closed_at, now()) - opened_at))/60.0 as mttr,
       rca_link as link
from public.incidents
where opened_at >= now() - interval '30 days'
order by opened_at desc;

-- 16) Geo flow
create or replace view public.kpi_geo_flow as
select origin_band, count(*) as visits
from public.visits_origin_bands
where ts >= now() - interval '30 days'
group by origin_band
order by visits desc;

-- 17) Lane contribution
create or replace view public.kpi_lane_contribution as
select corridor, count(*) as trips
from public.corridor_trips
where ts >= now() - interval '30 days'
group by corridor
order by trips desc;
