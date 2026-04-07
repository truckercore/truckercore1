-- docs/supabase/kpi_eval.sql
-- Helper for KPI evaluator: raise alarm once within a dedupe window and optional banner assist is handled in Edge Function.
-- Run this in Supabase SQL editor before deploying the eval_kpis function.

set search_path = public;

-- De-duped alarm raiser
-- If an alarm with the same key & level exists in the last p_dedupe_minutes, do nothing; otherwise insert.
-- Expects a table public.kpi_alarms(key text, observed numeric, level text, info jsonb, ts timestamptz default now()).
create or replace function public.svc_raise_kpi_alarm_once(
  p_key text,
  p_observed numeric,
  p_level text,
  p_dedupe_minutes int default 10,
  p_info jsonb default '{}'::jsonb
) returns void
language plpgsql
security definer
as $$
begin
  -- basic validation
  if p_key is null or p_key = '' then
    raise exception 'missing_key' using errcode = '22023';
  end if;
  if p_level not in ('warn','crit') then
    raise exception 'invalid_level' using errcode = '22023';
  end if;

  -- de-dupe on (key, level) within recent window
  if exists (
    select 1 from public.kpi_alarms a
    where a.key = p_key
      and a.level = p_level
      and a.ts >= now() - make_interval(mins => greatest(p_dedupe_minutes, 1))
  ) then
    return; -- skip insert
  end if;

  -- Insert the alarm
  insert into public.kpi_alarms(key, observed, level, info)
  values (p_key, p_observed, p_level, coalesce(p_info, '{}'::jsonb));
end;
$$;

revoke all on function public.svc_raise_kpi_alarm_once(text, numeric, text, int, jsonb) from public;
-- Edge Functions use the service role key; grant execute to service_role only.
grant execute on function public.svc_raise_kpi_alarm_once(text, numeric, text, int, jsonb) to service_role;

-- Notes:
-- - The evaluator function (supabase/functions/eval_kpis) calls this RPC.
-- - Ensure views/tables exist: kpi_latency_p95_24h, kpi_trial_to_paid_60d, kpi_siem_success_24h, kpi_thresholds,
--   status_banner table and set_status_banner RPC.
-- - Keep your scheduler (e.g., every 2 minutes) to invoke eval_kpis regularly.
