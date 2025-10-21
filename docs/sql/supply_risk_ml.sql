-- Supply chain risk & external signals
create table if not exists external_events (
  id bigserial primary key,
  org_id uuid not null,
  event_time timestamptz not null,
  source text not null,
  event_type text not null,
  location text,
  payload jsonb not null
);
create table if not exists risk_predictions (
  id bigserial primary key,
  org_id uuid not null,
  scope text not null,
  model_version_id uuid references ml_model_versions(id),
  risk numeric not null,
  horizon text,
  details jsonb,
  created_at timestamptz default now()
);

alter table external_events enable row level security;
alter table risk_predictions enable row level security;

create policy ee_sel on external_events for select using (org_id = app_org_id());
create policy ee_all on external_events for all using (org_id = app_org_id()) with check (org_id = app_org_id());

create policy rp_sel on risk_predictions for select using (org_id = app_org_id());
create policy rp_ins on risk_predictions for insert with check (org_id = app_org_id());
