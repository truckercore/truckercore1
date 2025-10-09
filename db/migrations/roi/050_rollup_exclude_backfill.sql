begin;

-- Recreate daily rollup to exclude backfilled rows from live KPIs
-- Safe to re-run: drop and recreate the materialized view and preserve grants separately.

drop materialized view if exists public.ai_roi_rollup_day;

create materialized view public.ai_roi_rollup_day as
select
  org_id,
  date_trunc('day', created_at) as day,
  sum(amount_cents) filter (where event_type='fuel_savings'            and coalesce(is_backfill,false) = false) as fuel_cents,
  sum(amount_cents) filter (where event_type='hos_violation_avoidance' and coalesce(is_backfill,false) = false) as hos_cents,
  sum(amount_cents) filter (where event_type='promo_uplift'            and coalesce(is_backfill,false) = false) as promo_cents,
  sum(amount_cents) filter (where coalesce(is_backfill,false) = false)                                        as total_cents
from public.ai_roi_events
group by 1,2;

-- Ensure refresh function exists and also stamps freshness
create or replace function public.ai_roi_rollup_refresh()
returns void language plpgsql as $$
begin
  refresh materialized view concurrently public.ai_roi_rollup_day;
  insert into public.ai_roi_rollup_meta(id, last_refresh_at)
  values (true, now())
  on conflict (id) do update set last_refresh_at = excluded.last_refresh_at;
end;$$;

-- Re-grant read access
grant select on public.ai_roi_rollup_day to authenticated, anon;

commit;
