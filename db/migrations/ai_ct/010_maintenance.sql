begin;

create table if not exists maintenance_events (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null,
  odometer_km numeric,
  fault_codes text[],
  ts timestamptz default now()
);

create table if not exists maintenance_predictions (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null,
  model_version_id uuid references ai_model_versions(id),
  failure_risk numeric not null, -- 0..1
  horizon_days int not null,
  created_at timestamptz default now()
);

alter table maintenance_events enable row level security;
alter table maintenance_predictions enable row level security;

create policy maint_service on maintenance_events
for all to service_role using (true) with check (true);

create policy maint_service2 on maintenance_predictions
for all to service_role using (true) with check (true);

commit;
