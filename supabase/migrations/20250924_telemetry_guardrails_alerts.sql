-- 20250924_telemetry_guardrails_alerts.sql
-- Purpose: Event codes, guardrail rollup/status, webhook alert using pg_net.
-- Idempotent and compatible with existing telemetry schema in this repo.

-- 0) Prereqs
create extension if not exists pg_net;

-- 1) Event codes (for alerts_events.code usage)
create table if not exists public.alert_codes (
  code text primary key,
  note text null,
  created_at timestamptz not null default now()
);
insert into public.alert_codes(code, note) values
  ('TELEMETRY_SAMPLING_LOW',  'Sampling hit rate below threshold'),
  ('TELEMETRY_BATTERY_DRAIN', 'Battery drain above threshold'),
  ('TELEMETRY_PARKING_STALE', 'Parking freshness too old'),
  ('TELEMETRY_GNSS_LOW',      'GNSS low/lost rate above threshold'),
  ('TELEMETRY_CLOCK_SKEW',    'Clock skew drop rate above threshold'),
  ('TELEMETRY_GUARDRAIL_BREACH', 'Guardrail rollup breach')
on conflict (code) do nothing;

-- 2) Helper: safe worst parking freshness (minutes) if table exists
create or replace function public.get_worst_parking_freshness_min()
returns numeric
language plpgsql
stable
as $$
declare v numeric; begin
  if to_regclass('public.parking_state') is null then
    return null;  -- parking table not present; treat as unknown
  end if;
  select extract(epoch from (now() - max(last_update)))/60.0 into v from public.parking_state;
  return v;
end $$;

-- 3) Guardrails rollup (24h) — add worst_parking_freshness_min while preserving existing columns
create or replace view public.v_guardrails_24h as
select
  avg(vs.hit_rate_pct) as sampling_hit_rate_pct,
  avg(vb.drain_pct_per_hr) as battery_drain_pct_per_hr,
  avg(vg.gnss_low_rate_pct) as gnss_low_rate_pct,
  avg(vc.skew_drop_rate_pct) as clock_skew_drop_rate_pct,
  public.get_worst_parking_freshness_min() as worst_parking_freshness_min
from public.telemetry_sessions s
left join public.v_sampling_hit_rate vs on vs.session_id = s.id
left join public.v_battery_drain_per_hr vb on vb.session_id = s.id
left join public.v_gnss_low_rate vg on vg.session_id = s.id
left join public.v_clock_skew_rate vc on vc.session_id = s.id
where s.started_at >= now() - interval '24 hours';

-- 4) Red/green status based on thresholds
create or replace view public.telemetry_guardrail_status as
select
  coalesce(v.sampling_hit_rate_pct, 100) >= 85.0 as sampling_ok,
  coalesce(v.battery_drain_pct_per_hr, 0) <= 5.0  as battery_ok,
  coalesce(v.worst_parking_freshness_min, 0) <= 60.0 as parking_ok,
  coalesce(v.gnss_low_rate_pct, 0) <= 15.0 as gnss_ok,
  coalesce(v.clock_skew_drop_rate_pct, 0) <= 2.0 as skew_ok
from public.v_guardrails_24h v;

-- 5) Webhook plumbing (server-only)
create or replace function public._post_json(url text, payload jsonb)
returns void language plpgsql security definer as $$
begin
  perform pg_net.http_post(url := url, headers := '{"content-type":"application/json"}'::jsonb, body := payload);
exception when others then
  raise notice 'webhook failed: %', sqlerrm;
end $$;
revoke all on function public._post_json(text,jsonb) from public, anon, authenticated;
grant execute on function public._post_json(text,jsonb) to service_role;

-- 6) Alert runner (server-only)
create or replace function public.telemetry_guardrail_alert()
returns void language plpgsql security definer as $$
declare s record; hook text; begin
  select * into s from public.telemetry_guardrail_status;
  if s is null then return; end if;
  if (not s.sampling_ok or not s.battery_ok or not s.parking_ok or not s.gnss_ok or not s.skew_ok) then
    hook := current_setting('app.guardrails_webhook', true);
    if coalesce(hook,'') <> '' then
      perform public._post_json(hook,
        jsonb_build_object(
          'title','Telemetry guardrails breach',
          'code','TELEMETRY_GUARDRAIL_BREACH',
          'status', row_to_json(s),
          'v_guardrails_24h', (select row_to_json(v) from public.v_guardrails_24h v),
          'ts', now()
        )
      );
    end if;
  end if;
end $$;
revoke all on function public.telemetry_guardrail_alert() from public, anon, authenticated;
grant execute on function public.telemetry_guardrail_alert() to service_role;

-- 7) Sanity helpers (optional copy/paste)
-- select * from public.v_guardrails_24h;
-- select * from public.telemetry_guardrail_status;
-- select now() - max(observed_at) as gps_lag from public.gps_samples;
