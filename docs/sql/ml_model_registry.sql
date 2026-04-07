-- Model registry & monitoring (multi-tenant)
do $$ begin
  create type ml_model_kind as enum ('eta','pricing','bid_risk','carrier_match','demand_forecast','safety_score','maintenance');
exception when duplicate_object then null; end $$;

create table if not exists ml_models (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  kind ml_model_kind not null,
  name text not null,
  owner text,
  created_at timestamptz default now(),
  unique (org_id, kind, name)
);

create table if not exists ml_model_versions (
  id uuid primary key default gen_random_uuid(),
  model_id uuid not null references ml_models(id) on delete cascade,
  version text not null,
  artifact_uri text not null,
  training_started_at timestamptz,
  training_completed_at timestamptz,
  metrics jsonb,
  status text not null default 'ready' check (status in ('ready','training','archived')),
  created_at timestamptz default now(),
  unique (model_id, version)
);
create index if not exists idx_mlmv_model on ml_model_versions(model_id);

create table if not exists ml_predictions (
  id bigserial primary key,
  org_id uuid not null,
  kind ml_model_kind not null,
  model_version_id uuid references ml_model_versions(id),
  request_id text,
  entity_id uuid,
  features jsonb,
  prediction jsonb not null,
  predicted_at timestamptz default now(),
  latency_ms int,
  source text check (source in ('edge_fn','rpc','batch'))
);
create index if not exists idx_mlp_org on ml_predictions(org_id);
create index if not exists idx_mlp_kind on ml_predictions(kind);
create index if not exists idx_mlp_entity on ml_predictions(entity_id);
create index if not exists idx_mlp_time on ml_predictions(predicted_at);

create table if not exists ml_outcomes (
  id bigserial primary key,
  org_id uuid not null,
  kind ml_model_kind not null,
  entity_id uuid not null,
  outcome jsonb not null,
  recorded_at timestamptz default now(),
  unique (org_id, kind, entity_id)
);
create index if not exists idx_mlo_org_kind_entity on ml_outcomes(org_id, kind, entity_id);

create table if not exists ml_backtests (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  kind ml_model_kind not null,
  model_version_id uuid references ml_model_versions(id),
  window_start timestamptz not null,
  window_end timestamptz not null,
  metrics jsonb,
  completed_at timestamptz default now()
);
create index if not exists idx_mlbt_org_kind on ml_backtests(org_id, kind);

-- RLS
alter table ml_models enable row level security;
alter table ml_model_versions enable row level security;
alter table ml_predictions enable row level security;
alter table ml_outcomes enable row level security;
alter table ml_backtests enable row level security;

create policy ml_models_sel on ml_models for select using (org_id = app_org_id());
create policy ml_models_ins on ml_models for insert with check (org_id = app_org_id());
create policy ml_models_upd on ml_models for update using (org_id = app_org_id()) with check (org_id = app_org_id());

create policy ml_model_versions_sel on ml_model_versions for select
using (exists (select 1 from ml_models m where m.id = model_id and m.org_id = app_org_id()));
create policy ml_model_versions_all on ml_model_versions for all
using (exists (select 1 from ml_models m where m.id = model_id and m.org_id = app_org_id()))
with check (exists (select 1 from ml_models m where m.id = model_id and m.org_id = app_org_id()));

create policy ml_predictions_sel on ml_predictions for select using (org_id = app_org_id());
create policy ml_predictions_ins on ml_predictions for insert with check (org_id = app_org_id());

create policy ml_outcomes_sel on ml_outcomes for select using (org_id = app_org_id());
create policy ml_outcomes_all on ml_outcomes for all using (org_id = app_org_id()) with check (org_id = app_org_id());

create policy ml_backtests_sel on ml_backtests for select using (org_id = app_org_id());
create policy ml_backtests_all on ml_backtests for all using (org_id = app_org_id()) with check (org_id = app_org_id());
