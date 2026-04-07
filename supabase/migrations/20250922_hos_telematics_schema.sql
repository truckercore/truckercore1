-- 20250922_hos_telematics_schema.sql
-- Safe-to-rerun scaffolding for normalized telematics/HOS ingestion, labels, features, registry, and views.

-- Map vendor payloads to normalized fields
create table if not exists public.telematics_vendor_adapters (
  id uuid primary key default gen_random_uuid(),
  vendor text not null,
  mapping jsonb not null,
  enabled boolean not null default true,
  created_at timestamptz default now()
);
create index if not exists idx_tel_vendor_enabled on public.telematics_vendor_adapters(vendor) where enabled;

-- HOS status enum
do $$ begin
  create type public.hos_status as enum ('off_duty','sleeper','driving','on_duty_not_driving');
exception when duplicate_object then null; end $$;

-- Raw HOS events (normalized)
create table if not exists public.raw_hos_events (
  id bigserial primary key,
  org_id uuid not null,
  driver_id uuid not null,
  vehicle_id uuid,
  status public.hos_status not null,
  effective_at timestamptz not null,
  src_vendor text,
  raw jsonb not null default '{}'::jsonb
);
create index if not exists idx_hos_driver_time on public.raw_hos_events(driver_id, effective_at desc);

-- Raw telematics (normalized)
create table if not exists public.raw_telematics (
  id bigserial primary key,
  org_id uuid not null,
  driver_id uuid,
  vehicle_id uuid,
  ts timestamptz not null,
  lat double precision, lon double precision,
  speed_mph double precision, brake boolean, rpm int,
  engine_on boolean, ecu jsonb default '{}'::jsonb,
  src_vendor text,
  raw jsonb default '{}'::jsonb
);
create index if not exists idx_tel_vehicle_ts on public.raw_telematics(vehicle_id, ts desc);
create index if not exists idx_tel_org_ts on public.raw_telematics(org_id, ts desc);

-- Optional UI/voice interactions (opt-in)
create table if not exists public.ui_interactions (
  id bigserial primary key,
  driver_id uuid not null,
  ts timestamptz not null default now(),
  intent text not null,
  transcript text,
  stress_hint double precision,
  raw jsonb not null default '{}'::jsonb
);
create index if not exists idx_ui_driver_ts on public.ui_interactions(driver_id, ts desc);

-- Wearables consent + biometrics (consent-gated)
create table if not exists public.wellness_optin (
  driver_id uuid primary key,
  org_id uuid not null,
  consent boolean not null default false,
  updated_at timestamptz not null default now()
);
create table if not exists public.raw_biometrics (
  id bigserial primary key,
  driver_id uuid not null,
  ts timestamptz not null,
  heart_rate int,
  hrv_ms int,
  sleep_last_night_min int,
  raw jsonb default '{}'::jsonb
);
create index if not exists idx_bio_driver_ts on public.raw_biometrics(driver_id, ts desc);

-- Consent trigger
create or replace function public.bio_consent_guard() returns trigger
language plpgsql as $$
declare ok boolean := false;
begin
  select consent into ok from public.wellness_optin where driver_id=new.driver_id;
  if not coalesce(ok,false) then
    raise exception 'biometrics require consent';
  end if;
  return new;
end$$;
drop trigger if exists trg_bio_consent on public.raw_biometrics;
create trigger trg_bio_consent before insert on public.raw_biometrics
for each row execute function public.bio_consent_guard();

-- External context
create table if not exists public.ext_weather (
  id bigserial primary key,
  ts timestamptz not null,
  lat double precision, lon double precision,
  temp_c double precision, precip_mm double precision,
  cond text, src text
);
create table if not exists public.ext_traffic (
  id bigserial primary key,
  ts timestamptz not null,
  road_segment_id text,
  speed_kph double precision,
  congestion_index double precision,
  incidents jsonb default '[]'::jsonb
);

-- Parking snapshots (POI time series)
create table if not exists public.poi_parking_state (
  poi_id uuid,
  ts timestamptz not null,
  spaces_free int, confidence double precision,
  primary key (poi_id, ts)
);

-- Jurisdiction rule set
create table if not exists public.hos_rules (
  id uuid primary key default gen_random_uuid(),
  jurisdiction text not null unique,
  max_drive_min int not null,
  min_break_min int not null,
  window_min int not null,
  updated_at timestamptz default now()
);

-- Labels (ground truth outcomes)
create table if not exists public.hos_break_outcomes (
  id bigserial primary key,
  org_id uuid not null,
  driver_id uuid not null,
  session_id uuid,
  break_start timestamptz not null,
  break_end timestamptz not null,
  lat double precision, lon double precision,
  compliant boolean not null,
  rule_applied text not null,
  source text not null default 'auto',
  created_at timestamptz default now()
);
create index if not exists idx_outcome_driver_time on public.hos_break_outcomes(driver_id, break_start desc);

-- Model-ready features (decision-time rows)
create table if not exists public.hos_features (
  id bigserial primary key,
  driver_id uuid not null,
  ts timestamptz not null,
  label_break_within_min int,
  label_violation boolean,
  minutes_since_last_break int,
  minutes_driving_last_24h int,
  duty_state text,
  upcoming_route_complexity double precision,
  cumulative_fatigue double precision,
  risk_score double precision,
  eta_minutes_remaining int,
  weather_severity double precision,
  traffic_index double precision,
  parking_avail_score double precision,
  is_night boolean,
  is_holiday boolean,
  jurisdiction text not null,
  meta jsonb not null default '{}'::jsonb
);
create index if not exists idx_hos_features_ts on public.hos_features(ts desc);

-- Outcome recording helper
create or replace function public.hos_record_outcome(
  p_org uuid, p_driver uuid, p_session uuid,
  p_break_start timestamptz, p_break_end timestamptz,
  p_lat double precision, p_lon double precision,
  p_compliant boolean, p_rule text, p_source text default 'auto'
) returns bigint
language plpgsql security definer
as $$
declare new_id bigint;
begin
  insert into public.hos_break_outcomes(org_id,driver_id,session_id,break_start,break_end,lat,lon,compliant,rule_applied,source)
  values (p_org,p_driver,p_session,p_break_start,p_break_end,p_lat,p_lon,p_compliant,p_rule,p_source)
  returning id into new_id;
  return new_id;
end $$;
-- grant to service_role (ignore if supabase role missing)
do $$ begin execute $$grant execute on function public.hos_record_outcome(uuid,uuid,uuid,timestamptz,timestamptz,double precision,double precision,boolean,text,text) to service_role$$; exception when others then null; end $$;

-- Model registry + metrics
create table if not exists public.ai_models (
  model_key text not null,
  version text not null,
  created_at timestamptz default now(),
  artifact_url text not null,
  params jsonb not null default '{}',
  metrics jsonb not null default '{}',
  primary key (model_key, version)
);
create table if not exists public.ai_metrics (
  id bigserial primary key,
  model_key text not null,
  version text not null,
  metric text not null,
  value double precision not null,
  ts timestamptz default now()
);
create index if not exists idx_ai_metric_key_ts on public.ai_metrics(model_key, ts desc);

-- Feature engineering helpers (views)
create or replace view public.v_last_break as
select driver_id, max(break_end) as last_break_end
from public.hos_break_outcomes group by 1;

create or replace view public.v_driver_duty_agg as
with seg as (
  select driver_id, status, effective_at,
         lead(effective_at,1,now()) over (partition by driver_id order by effective_at) as next_at
  from public.raw_hos_events
)
select driver_id,
  sum(case when status='driving' then extract(epoch from (next_at - effective_at)) end)::int as drive_sec,
  sum(case when status in ('on_duty_not_driving','driving') then extract(epoch from (next_at - effective_at)) end)::int as on_duty_sec
from seg group by 1;

create or replace view public.v_env_join as
select t.vehicle_id, t.ts, t.lat, t.lon,
  (select w.cond from public.ext_weather w order by abs(extract(epoch from (w.ts - t.ts))) limit 1) as weather_cond,
  (select tr.congestion_index from public.ext_traffic tr order by abs(extract(epoch from (tr.ts - t.ts))) limit 1) as traffic_idx
from public.raw_telematics t;
