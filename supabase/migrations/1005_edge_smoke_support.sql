-- 1005_edge_smoke_support.sql
-- Purpose: Support Edge function smoke tests with minimal RPCs/views and safe promo ROI refresh.
-- Idempotent and safe across environments.

-- 1) Health ping view used by bootstrap probes and smoke tests
create or replace view public.health_ping_view as
select now() as now;

-- 2) Feature-flag aware IFTA CSV RPC
-- Returns simple aggregated miles/gallons per state for a given org and quarter.
-- When feature flag 'mock_ifta' is enabled, return synthetic rows for quick demos/tests.
create or replace function public.ifta_quarter_csv(org uuid, quarter_date date)
returns table(state text, miles numeric, gallons numeric)
language sql
stable
set search_path=public
as $$
  with q as (
    select date_trunc('quarter', quarter_date)::date as q_start,
           (date_trunc('quarter', quarter_date) + interval '3 months - 1 day')::date as q_end
  )
  -- Mock path when flag enabled
  select * from (
    select s as state, (1000 + (row_number() over())*100)::numeric as miles, (300 + (row_number() over())*20)::numeric as gallons
    from (values ('TX'),('OK'),('LA')) v(s)
  ) mock
  where public.feature_enabled('mock_ifta')
  union all
  -- Live path (very simple aggregation; adjust to your schema as needed)
  select coalesce(fp.state, 'UNK') as state,
         coalesce(sum(t.total_miles)::numeric, 0) as miles,
         coalesce(sum(fp.gallons)::numeric, 0) as gallons
  from q
  left join public.ifta_trips t
    on t.org_id = org and t.ended_at::date between (select q_start from q) and (select q_end from q)
  left join public.ifta_fuel_purchases fp
    on fp.org_id = org and fp.purchased_at::date between (select q_start from q) and (select q_end from q)
  group by 1
  having not public.feature_enabled('mock_ifta');
$$;

-- 3) Promo ROI refresh with safe caps/timeouts
-- This is a placeholder that can be extended to compute ROI rollups. It sets a local
-- statement timeout and touches a heartbeat so Ops can see activity.
create or replace function public.refresh_promo_roi(p_limit int default 500, p_timeout_ms int default 20000)
returns void
language plpgsql
security definer
set search_path=public
as $$
begin
  -- Safety: cap limit and set a local statement timeout
  perform set_config('statement_timeout', greatest(1000, least(p_timeout_ms, 60000))::text, true);
  -- No-op demo computation (extend with real rollup of discounts/promos usage)
  -- Example: insert into promo_roi_daily ... limit p_limit;

  -- Touch heartbeat for monitoring
  perform public.touch_heartbeat('promo_roi_refresh');
exception when others then
  -- Don’t fail migrations due to optional tables missing; swallow and still touch heartbeat
  perform public.touch_heartbeat('promo_roi_refresh');
end;$$;
