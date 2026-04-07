begin;

alter table ai_roi_events
  add column if not exists is_backfill boolean not null default false;

create or replace view v_roi_kpis_30d as
select org_id,
  sum(amount_cents) filter (where event_type='fuel_savings' and not is_backfill and created_at>=now()-interval '30 days') as fuel_cents_30d,
  sum(amount_cents) filter (where event_type='hos_violation_avoidance' and not is_backfill and created_at>=now()-interval '30 days') as hos_cents_30d,
  sum(amount_cents) filter (where event_type='promo_uplift' and not is_backfill and created_at>=now()-interval '30 days') as promo_cents_30d,
  sum(amount_cents) filter (where not is_backfill and created_at>=now()-interval '30 days') as total_cents_30d
from ai_roi_events
group by org_id;

alter table ai_roi_events add column if not exists idem_key text;
create unique index if not exists uniq_backfill_idem
  on ai_roi_events(org_id, event_type, idem_key)
  where is_backfill = true and idem_key is not null;

commit;
