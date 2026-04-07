begin;

-- Core ELD session
create table if not exists public.eld_sessions (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null,
  vehicle_id uuid not null,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  device_id text not null,
  org_id uuid not null,
  unique (driver_id, vehicle_id, started_at)
);

-- HOS duty status timeline
do $$ begin
  if not exists (select 1 from pg_type where typname = 'hos_status') then
    create type hos_status as enum ('off_duty','sleeper','driving','on_duty_not_driving');
  end if;
end $$;

create table if not exists public.hos_duty_status (
  id bigserial primary key,
  session_id uuid not null references public.eld_sessions(id) on delete cascade,
  status hos_status not null,
  effective_at timestamptz not null,
  location geography(Point, 4326),
  source text not null default 'device', -- device|voice|manual
  note text
);
create index if not exists idx_hos_session_time on public.hos_duty_status(session_id, effective_at desc);

-- Raw ELD events
create table if not exists public.eld_events (
  id bigserial primary key,
  session_id uuid not null references public.eld_sessions(id) on delete cascade,
  ts timestamptz not null default now(),
  lat double precision, lon double precision,
  speed_mph double precision, engine_on boolean,
  dtc_code text, raw jsonb not null default '{}'::jsonb
);
create index if not exists idx_eld_events_session_ts on public.eld_events(session_id, ts desc);

-- Wellness opt-in
create table if not exists public.wellness_optin (
  driver_id uuid primary key,
  org_id uuid not null,
  consent boolean not null default false,
  updated_at timestamptz not null default now()
);

-- Wearable telemetry
create table if not exists public.driver_wearable_telemetry (
  id bigserial primary key,
  driver_id uuid not null,
  ts timestamptz not null,
  heart_rate int,
  hrv_ms int,
  stress_index double precision,
  fatigue_score double precision,
  raw jsonb not null default '{}'::jsonb
);
create index if not exists idx_wearable_driver_ts on public.driver_wearable_telemetry(driver_id, ts desc);

-- DVIR
create table if not exists public.dvir_reports (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null,
  vehicle_id uuid not null,
  org_id uuid not null,
  created_at timestamptz not null default now(),
  pretrip boolean not null default true,
  defects jsonb not null default '[]'::jsonb,
  suggested_by_ai jsonb not null default '[]'::jsonb,
  signed_by_driver boolean not null default false,
  signed_by_mechanic boolean not null default false
);

-- HOS break recommendations
create table if not exists public.hos_break_recommendations (
  id bigserial primary key,
  driver_id uuid not null,
  session_id uuid not null references public.eld_sessions(id) on delete cascade,
  computed_at timestamptz not null default now(),
  violation_eta timestamptz,
  recommended_at timestamptz,
  poi_id uuid,
  note text,
  rationale jsonb not null default '{}'::jsonb
);

-- Risk & scorecards
create table if not exists public.driver_risk_scores (
  driver_id uuid not null,
  computed_at timestamptz not null default now(),
  risk_score double precision not null,
  factors jsonb not null default '{}'::jsonb,
  primary key(driver_id, computed_at)
);

create table if not exists public.driver_scorecards (
  driver_id uuid not null,
  month date not null,
  safety_score double precision,
  hos_compliance double precision,
  fuel_efficiency double precision,
  on_time_pct double precision,
  rewards_payload jsonb not null default '{}'::jsonb,
  primary key(driver_id, month)
);

-- Owner-operator artifacts
create table if not exists public.fuel_fill_events (
  id bigserial primary key,
  driver_id uuid not null,
  org_id uuid not null,
  ts timestamptz not null,
  gallons double precision not null,
  price_per_gallon double precision not null,
  location geography(Point, 4326),
  merchant text
);

create table if not exists public.expenses (
  id bigserial primary key,
  driver_id uuid not null,
  org_id uuid not null,
  ts timestamptz not null default now(),
  category text not null,
  amount_cents int not null,
  receipt jsonb not null default '[]'::jsonb,
  note text
);

create table if not exists public.invoices (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null,
  org_id uuid not null,
  load_id uuid,
  issue_date date not null default current_date,
  due_date date,
  subtotal_cents int not null,
  tax_cents int not null default 0,
  total_cents int not null,
  status text not null default 'draft'
);

-- Minimal RLS examples
alter table public.eld_sessions enable row level security;
create policy if not exists eld_sessions_self on public.eld_sessions for select using (auth.uid() = driver_id);

alter table public.hos_duty_status enable row level security;
create policy if not exists hos_self on public.hos_duty_status
for select using (exists (select 1 from public.eld_sessions s where s.id = session_id and s.driver_id = auth.uid()));

commit;