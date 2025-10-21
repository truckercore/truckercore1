-- Demand forecasting
create table if not exists demand_forecasts (
  id bigserial primary key,
  org_id uuid not null,
  horizon text not null check (horizon in ('7d','14d','28d')),
  scope text not null,
  model_version_id uuid references ml_model_versions(id),
  forecast jsonb not null,
  created_at timestamptz default now(),
  unique (org_id, horizon, scope, created_at)
);

alter table demand_forecasts enable row level security;
create policy df_sel on demand_forecasts for select using (org_id = app_org_id());
create policy df_ins on demand_forecasts for insert with check (org_id = app_org_id());
