-- Marketplace ML signals/predictions
create table if not exists pricing_signals (
  id bigserial primary key,
  org_id uuid not null,
  load_id uuid not null,
  lane_hash text not null,
  demand_idx numeric, supply_idx numeric, seasonality_idx numeric,
  historical_rate_cents int,
  features jsonb,
  created_at timestamptz default now(),
  unique (org_id, load_id)
);

create table if not exists pricing_predictions (
  id bigserial primary key,
  org_id uuid not null,
  load_id uuid not null,
  model_version_id uuid references ml_model_versions(id),
  predicted_rate_cents int not null,
  band_low_cents int, band_high_cents int,
  prediction jsonb,
  created_at timestamptz default now(),
  unique (org_id, load_id)
);

create table if not exists bid_risk_scores (
  id bigserial primary key,
  org_id uuid not null,
  tender_id uuid not null,
  bid_id uuid not null,
  model_version_id uuid references ml_model_versions(id),
  risk_score numeric not null,
  reasons jsonb,
  created_at timestamptz default now(),
  unique (org_id, bid_id)
);

create table if not exists carrier_match_scores (
  id bigserial primary key,
  org_id uuid not null,
  load_id uuid not null,
  carrier_org_id uuid not null,
  model_version_id uuid references ml_model_versions(id),
  score numeric not null,
  features jsonb,
  created_at timestamptz default now(),
  unique (org_id, load_id, carrier_org_id)
);

alter table pricing_signals enable row level security;
alter table pricing_predictions enable row level security;
alter table bid_risk_scores enable row level security;
alter table carrier_match_scores enable row level security;

create policy ps_sel on pricing_signals for select using (org_id = app_org_id());
create policy ps_all on pricing_signals for all using (org_id = app_org_id()) with check (org_id = app_org_id());

create policy pp_sel on pricing_predictions for select using (org_id = app_org_id());
create policy pp_all on pricing_predictions for all using (org_id = app_org_id()) with check (org_id = app_org_id());

create policy br_sel on bid_risk_scores for select using (org_id = app_org_id());
create policy br_all on bid_risk_scores for all using (org_id = app_org_id()) with check (org_id = app_org_id());

create policy cm_sel on carrier_match_scores for select using (org_id = app_org_id());
create policy cm_all on carrier_match_scores for all using (org_id = app_org_id()) with check (org_id = app_org_id());
