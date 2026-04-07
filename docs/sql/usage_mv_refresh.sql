-- Incremental MV refresh (no table locks, cheap)
-- Replace full refresh with fast upsert of the last N days

create or replace function public.usage_rollup_incremental(days_back int default 7)
returns int language plpgsql as $$
declare
  n int := 0;
begin
  with delta as (
    select org_id,
           feature_key,
           date_trunc('month', at) as period,
           sum(units) as total_units,
           count(distinct user_id) as distinct_users
    from public.usage_events
    where at >= now() - make_interval(days=>days_back)
    group by 1,2,3
  )
  insert into public.usage_monthly(org_id, feature_key, period, total_units, distinct_users)
  select * from delta
  on conflict (org_id, feature_key, period) do update
    set total_units = excluded.total_units,
        distinct_users = excluded.distinct_users;
  get diagnostics n = row_count;
  return n;
end $$;

-- Scheduler: run hourly with days_back => 3
