begin;

create or replace view v_roi_kpis_30d as
select
  org_id,
  coalesce(sum(amount_cents) filter (where event_type = 'fuel_savings'            and created_at >= now() - interval '30 days'), 0) as fuel_cents_30d,
  coalesce(sum(amount_cents) filter (where event_type = 'hos_violation_avoidance' and created_at >= now() - interval '30 days'), 0) as hos_cents_30d,
  coalesce(sum(amount_cents) filter (where event_type = 'promo_uplift'            and created_at >= now() - interval '30 days'), 0) as promo_cents_30d,
  coalesce(sum(amount_cents) filter (where created_at >= now() - interval '30 days'), 0) as total_cents_30d
from ai_roi_events
group by org_id;

grant select on v_roi_kpis_30d to authenticated, anon;

commit;
