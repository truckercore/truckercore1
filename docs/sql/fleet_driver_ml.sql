-- Fleet/Driver ML
create table if not exists telematics_snapshots (
  id bigserial primary key,
  org_id uuid not null,
  vehicle_id uuid not null,
  ts timestamptz not null,
  odometer_km numeric, oil_pressure_kpa numeric, engine_temp_c numeric, fuel_pct numeric,
  dtc_codes text[],
  unique (org_id, vehicle_id, ts)
);

create table if not exists maintenance_predictions (
  id bigserial primary key,
  org_id uuid not null,
  vehicle_id uuid not null,
  model_version_id uuid references ml_model_versions(id),
  risk numeric not null,
  component text,
  recommended_action text,
  prediction jsonb,
  created_at timestamptz default now()
);
create index if not exists idx_maint_org_vehicle_time on maintenance_predictions(org_id, vehicle_id, created_at);

create table if not exists driver_safety_scores (
  id bigserial primary key,
  org_id uuid not null,
  driver_id uuid not null,
  score numeric not null,
  window text not null check (window in ('7d','30d')),
  components jsonb,
  updated_at timestamptz default now(),
  unique (org_id, driver_id, window)
);

create table if not exists fatigue_alerts (
  id bigserial primary key,
  org_id uuid not null,
  driver_id uuid not null,
  predicted_at timestamptz not null,
  risk numeric not null,
  evidence jsonb,
  acknowledged boolean default false,
  created_at timestamptz default now()
);

alter table telematics_snapshots enable row level security;
alter table maintenance_predictions enable row level security;
alter table driver_safety_scores enable row level security;
alter table fatigue_alerts enable row level security;

create policy t_snap_sel on telematics_snapshots for select using (org_id = app_org_id());
create policy t_snap_ins on telematics_snapshots for insert with check (org_id = app_org_id());

create policy maint_sel on maintenance_predictions for select using (org_id = app_org_id());
create policy maint_ins on maintenance_predictions for insert with check (org_id = app_org_id());

create policy dss_sel on driver_safety_scores for select using (org_id = app_org_id());
create policy dss_all on driver_safety_scores for all using (org_id = app_org_id()) with check (org_id = app_org_id());

create policy fat_sel on fatigue_alerts for select using (org_id = app_org_id());
create policy fat_all on fatigue_alerts for all using (org_id = app_org_id()) with check (org_id = app_org_id());
