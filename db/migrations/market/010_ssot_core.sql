begin;

create table if not exists fact_load_events (
  id bigserial primary key,
  org_id uuid not null,
  region_code text not null default 'US',
  load_id uuid not null,
  event_type text not null check (event_type in ('posted','matched','pickup','delivered','cancelled')),
  lane_from text,
  lane_to text,
  equipment text,
  weight_lb int,
  price_usd numeric,
  created_at timestamptz not null default now()
);
create index if not exists idx_fact_load_events_keys on fact_load_events(org_id, load_id, created_at desc);
create index if not exists idx_fact_load_events_lane on fact_load_events(lane_from, lane_to, equipment, created_at desc);

create table if not exists fact_telemetry_snap (
  id bigserial primary key,
  org_id uuid not null,
  region_code text not null default 'US',
  vehicle_id uuid not null,
  ts timestamptz not null,
  road_class text,
  speed_mph numeric,
  occupancy_pct numeric
);
create index if not exists idx_tel_lane on fact_telemetry_snap(region_code, road_class, ts desc);

create table if not exists fact_pricing (
  id bigserial primary key,
  org_id uuid not null,
  region_code text not null default 'US',
  lane_from text,
  lane_to text,
  equipment text,
  accepted_rate_usd numeric,
  posted_rate_usd numeric,
  observed_at timestamptz not null default now()
);
create index if not exists idx_pricing_lane on fact_pricing(lane_from, lane_to, equipment, observed_at desc);

alter table if exists ai_roi_events
  add column if not exists lane_from text,
  add column if not exists lane_to text,
  add column if not exists region_code text default 'US';

commit;
