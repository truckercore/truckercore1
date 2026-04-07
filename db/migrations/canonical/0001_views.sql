begin;

create or replace view v_org_roi_30d as
select
  org_id,
  sum(fuel_cents)   filter (where day >= current_date - 30) as fuel_cents_30d,
  sum(hos_cents)    filter (where day >= current_date - 30) as hos_cents_30d,
  sum(promo_cents)  filter (where day >= current_date - 30) as promo_cents_30d,
  sum(total_cents)  filter (where day >= current_date - 30) as total_cents_30d
from ai_roi_rollup_day
group by org_id;

-- (Optional) driver availability view placeholder
create or replace view v_driver_availability as
select
  s.org_id, s.driver_id,
  null::text as current_status,
  null::timestamptz as last_ping
from (select null::uuid as org_id, null::uuid as driver_id) s where false;

grant select on v_org_roi_30d, v_driver_availability to authenticated, anon;

commit;
