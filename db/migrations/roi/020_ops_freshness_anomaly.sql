begin;

-- Track last MV refresh (singleton)
create table if not exists public.ai_roi_rollup_meta (
  id boolean primary key default true,
  last_refresh_at timestamptz
);

-- Helper function to refresh + stamp
create or replace function public.ai_roi_rollup_refresh()
returns void language plpgsql as $$
begin
  refresh materialized view concurrently public.ai_roi_rollup_day;
  insert into public.ai_roi_rollup_meta(id, last_refresh_at)
  values (true, now())
  on conflict (id) do update set last_refresh_at = excluded.last_refresh_at;
end;
$$;

-- Spike detector: compare last 24h org total to 7-day median
create or replace view public.v_ai_roi_spike_alerts as
with daily as (
  select org_id, date_trunc('day', created_at) d, sum(amount_cents) amt
  from public.ai_roi_events
  where created_at >= now() - interval '8 days'
  group by 1,2
),
med as (
  select org_id,
         percentile_cont(0.5) within group (order by amt) as med_7d
  from daily
  where d < date_trunc('day', now())
  group by org_id
),
 today as (
  select org_id, sum(amt) as amt_today
  from daily
  where d = date_trunc('day', now())
  group by org_id
)
select t.org_id, t.amt_today, m.med_7d,
       case when m.med_7d = 0 then null else t.amt_today / m.med_7d end as multiple,
       now() as computed_at
from today t
join med m using (org_id)
where m.med_7d > 0 and t.amt_today > 3 * m.med_7d;

grant select on public.v_ai_roi_spike_alerts, public.ai_roi_rollup_meta to authenticated, anon;

commit;
