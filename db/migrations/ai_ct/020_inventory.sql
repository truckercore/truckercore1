begin;

create table if not exists inventory_levels (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  sku text not null,
  qty numeric not null,
  ts timestamptz default now()
);

create table if not exists inventory_forecasts (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  sku text not null,
  forecast_qty numeric not null,
  horizon_days int not null,
  model_version_id uuid references ai_model_versions(id),
  created_at timestamptz default now()
);

alter table inventory_levels enable row level security;
alter table inventory_forecasts enable row level security;

create policy inv_service on inventory_levels
for all to service_role using (true) with check (true);

create policy inv_service2 on inventory_forecasts
for all to service_role using (true) with check (true);

commit;
