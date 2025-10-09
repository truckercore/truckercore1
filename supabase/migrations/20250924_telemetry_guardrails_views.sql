-- 20250924_telemetry_guardrails_views.sql
-- Purpose: Guardrail status view, helper for optional parking freshness, 24h battery drain variant,
-- and idle-with-hints correlation. Idempotent and safe to re-run.

-- 1) Helper function: safely fetch worst parking freshness without hard dependency on a view/table
create or replace function public.get_worst_parking_freshness_min()
returns int
language plpgsql
stable
as $$
declare
  exists_rel boolean;
  v_min int;
begin
  -- Check if relation public.parking_guardrails exists
  select exists (
    select 1 from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'parking_guardrails'
  ) into exists_rel;

  if exists_rel then
    begin
      execute 'select max(worst_parking_freshness_min)::int from public.parking_guardrails' into v_min;
    exception when others then
      -- If column is missing or query fails, fallback to null
      v_min := null;
    end;
  else
    v_min := null;
  end if;

  return v_min;
end $$;

-- 2) Idle + BLE/Wi‑Fi hints correlation view
create or replace view public.v_idle_with_hints as
select i.*, coalesce(h.count_hint,0) as hint_count, h.first_hint, h.last_hint
from public.idle_events i
left join (
  select session_id,
         count(*) as count_hint,
         min(observed_at) as first_hint,
         max(observed_at) as last_hint
  from public.ble_wifi_hints
  group by session_id
) h using (session_id);

-- 3) Battery drain per hour (24h window variant)
create or replace view public.v_battery_drain_per_hr as
with w as (
  select session_id,
         min(observed_at) as t0,
         max(observed_at) as t1,
         (min(battery_pct))::float as p_min,
         (max(battery_pct))::float as p_max
  from public.battery_stats
  where observed_at >= now() - interval '24 hours'
  group by session_id
)
select
  s.id as session_id,
  s.org_id,
  -- Protect against tiny windows
  greatest(0.0, (w.p_max - w.p_min)) / greatest(extract(epoch from (w.t1 - w.t0))/3600.0, 0.1) as battery_drain_pct_per_hr
from public.telemetry_sessions s
left join w on w.session_id = s.id;

-- 4) Telemetry guardrail status booleans (red/green) using 24h rollup and helper
create or replace view public.telemetry_guardrail_status as
select
  -- Sampling hit rate >= 85%
  (select sampling_hit_rate_pct from public.v_guardrails_24h) >= 85 as sampling_ok,
  -- Battery drain per hour <= 5%/hr
  (select battery_drain_pct_per_hr from public.v_guardrails_24h) <= 5 as battery_ok,
  -- Worst parking freshness in minutes <= 60 (uses helper; defaults to null -> false when coalesced below)
  coalesce(public.get_worst_parking_freshness_min(), 999) <= 60 as parking_ok,
  -- GNSS low/lost rate <= 15%
  (select gnss_low_rate_pct from public.v_guardrails_24h) <= 15 as gnss_ok,
  -- Clock skew drop rate <= 2%
  (select clock_skew_drop_rate_pct from public.v_guardrails_24h) <= 2 as skew_ok;

-- Note: prune_telemetry(int) SECURITY DEFINER and grants were set in a prior migration.
-- These views are read-only and require no additional grants beyond default select via RLS policies.
