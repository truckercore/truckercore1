-- Financial/NLP automation
create table if not exists doc_extracts (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  doc_type text not null check (doc_type in ('invoice','bol','fuel_receipt')),
  source_uri text not null,
  extracted jsonb,
  confidence jsonb,
  status text not null default 'ok' check (status in ('ok','partial','failed')),
  created_at timestamptz default now()
);

create table if not exists dispute_risk (
  id bigserial primary key,
  org_id uuid not null,
  invoice_id uuid not null,
  model_version_id uuid references ml_model_versions(id),
  risk numeric not null,
  reasons jsonb,
  created_at timestamptz default now(),
  unique (org_id, invoice_id)
);

create table if not exists reconciliation_candidates (
  id bigserial primary key,
  org_id uuid not null,
  invoice_id uuid not null,
  payment_ref text,
  match_score numeric not null,
  evidence jsonb,
  created_at timestamptz default now(),
  unique (org_id, invoice_id, payment_ref)
);

alter table doc_extracts enable row level security;
alter table dispute_risk enable row level security;
alter table reconciliation_candidates enable row level security;

create policy de_sel on doc_extracts for select using (org_id = app_org_id());
create policy de_ins on doc_extracts for insert with check (org_id = app_org_id());

create policy dr_sel on dispute_risk for select using (org_id = app_org_id());
create policy dr_ins on dispute_risk for insert with check (org_id = app_org_id());

create policy rc_sel on reconciliation_candidates for select using (org_id = app_org_id());
create policy rc_ins on reconciliation_candidates for insert with check (org_id = app_org_id());
