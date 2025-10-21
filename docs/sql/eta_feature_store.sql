-- ETA feature store & inputs
create table if not exists trips (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  driver_id uuid,
  vehicle_id uuid,
  load_id uuid,
  origin_geohash text,
  dest_geohash text,
  planned_departure timestamptz,
  planned_arrival timestamptz,
  actual_departure timestamptz,
  actual_arrival timestamptz,
  route_polyline text,
  created_at timestamptz default now()
);
create index if not exists idx_trips_org on trips(org_id);
create index if not exists idx_trips_driver on trips(driver_id);
create index if not exists idx_trips_vehicle on trips(vehicle_id);
create index if not exists idx_trips_planned_departure on trips(planned_departure);
create index if not exists idx_trips_actual_arrival on trips(actual_arrival);

create table if not exists trip_segments (
  id bigserial primary key,
  org_id uuid not null,
  trip_id uuid not null references trips(id) on delete cascade,
  seq int not null,
  start_ts timestamptz not null,
  end_ts timestamptz,
  start_geohash text,
  end_geohash text,
  distance_km numeric,
  avg_speed_kmh numeric,
  traffic_index numeric,
  created_at timestamptz default now(),
  unique (trip_id, seq)
);
create index if not exists idx_seg_org_trip on trip_segments(org_id, trip_id);
create index if not exists idx_seg_start on trip_segments(start_ts);

create table if not exists weather_snapshots (
  id bigserial primary key,
  org_id uuid not null,
  ts timestamptz not null,
  geohash text not null,
  temp_c numeric, wind_mps numeric, precip_mm numeric, visibility_km numeric,
  code text,
  alert_level int,
  source text,
  unique (org_id, ts, geohash)
);
create index if not exists idx_weather_org_ts on weather_snapshots(org_id, ts);
create index if not exists idx_weather_geohash on weather_snapshots(geohash);

create table if not exists hos_snapshots (
  id bigserial primary key,
  org_id uuid not null,
  driver_id uuid not null,
  ts timestamptz not null,
  on_duty_mins int,
  driving_mins int,
  rest_required_at timestamptz,
  unique (org_id, driver_id, ts)
);

create table if not exists facility_stats (
  id bigserial primary key,
  org_id uuid not null,
  facility_id uuid not null,
  avg_load_mins int,
  p90_load_mins int,
  avg_unload_mins int,
  p90_unload_mins int,
  business_hours jsonb,
  updated_at timestamptz default now(),
  unique (org_id, facility_id)
);

create table if not exists eta_features (
  id bigserial primary key,
  org_id uuid not null,
  trip_id uuid not null references trips(id) on delete cascade,
  extracted_at timestamptz not null default now(),
  snapshot_ts timestamptz not null,
  features jsonb not null,
  label_seconds int,
  unique (org_id, trip_id, snapshot_ts)
);

-- RLS
alter table trips enable row level security;
alter table trip_segments enable row level security;
alter table weather_snapshots enable row level security;
alter table hos_snapshots enable row level security;
alter table facility_stats enable row level security;
alter table eta_features enable row level security;

create policy trips_sel on trips for select using (org_id = app_org_id());
create policy trips_all on trips for all using (org_id = app_org_id()) with check (org_id = app_org_id());

create policy seg_sel on trip_segments for select using (org_id = app_org_id());
create policy seg_all on trip_segments for all using (org_id = app_org_id()) with check (org_id = app_org_id());

create policy weather_sel on weather_snapshots for select using (org_id = app_org_id());
create policy weather_all on weather_snapshots for all using (org_id = app_org_id()) with check (org_id = app_org_id());

create policy hos_sel on hos_snapshots for select using (org_id = app_org_id());
create policy hos_all on hos_snapshots for all using (org_id = app_org_id()) with check (org_id = app_org_id());

create policy facility_sel on facility_stats for select using (org_id = app_org_id());
create policy facility_all on facility_stats for all using (org_id = app_org_id()) with check (org_id = app_org_id());

create policy eta_feat_sel on eta_features for select using (org_id = app_org_id());
create policy eta_feat_all on eta_features for all using (org_id = app_org_id()) with check (org_id = app_org_id());

-- Enforce org_id on client-writable table(s)
drop trigger if exists trips_enforce_org on trips;
create trigger trips_enforce_org before insert or update on trips
for each row execute function enforce_org_id();
