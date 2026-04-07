-- docs/supabase/roi_views.sql
-- ROI deck data views. Idempotent and safe to re-run.
-- Provides v_roi_pilot_summary using expected source tables.

create or replace view public.v_roi_pilot_summary as
select
  o.id as org_id,
  date_trunc('week', pr.created_at) as week,
  count(*) filter (where pr.status='approved') as redemptions,
  sum(coalesce(pr.discount_cents,0)) as discounts_cents,
  sum(coalesce(pr.estimated_gallons,0)) as est_gallons,
  avg(fc.delta_gallons) as avg_gallons_uplift,
  avg(pk.freshness_pct) as parking_freshness_pct
from promo_redemptions pr
join orgs o on o.id = pr.org_id
left join v_fuel_uplift fc on fc.org_id = o.id and fc.week = date_trunc('week', pr.created_at)
left join v_parking_freshness pk on pk.org_id = o.id and pk.week = date_trunc('week', pr.created_at)
group by 1,2;