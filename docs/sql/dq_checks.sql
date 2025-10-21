create or replace view dq_parking_freshness as
select poi_id, max(updated_at) as last_update, (now()-max(updated_at)) as age
from parking_slots group by poi_id
having now()-max(updated_at) > interval '48 hours';

create or replace view dq_promo_attribution as
select promo_id,
  sum(gallons_uplift) as uplift, sum(gallons_baseline) as baseline
from promo_attribution group by promo_id
having coalesce(sum(gallons_uplift),0) <= 0 or coalesce(sum(gallons_baseline),0) < 0;

create or replace view dq_fuel_price_outliers as
select f.station_id, f.price_cents,
       avg(price_cents) over (partition by region) as region_avg,
       abs(f.price_cents - avg(price_cents) over (partition by region)) as delta
from competitor_fuel_prices f
qualify delta > 3 * stddev_samp(price_cents) over (partition by region);
