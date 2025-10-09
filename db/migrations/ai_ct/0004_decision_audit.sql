begin;

-- Decision audit log to support explainability and compliance
create table if not exists ai_decision_audit (
  id bigserial primary key,
  model_key text not null,
  model_version_id uuid,
  correlation_id uuid,
  org_id uuid,
  user_id uuid,
  decision jsonb not null,
  xai jsonb,
  compliance_tags text[] default '{}',
  created_at timestamptz default now()
);
create index if not exists idx_ai_audit_model_time on ai_decision_audit (model_key, created_at desc);

alter table ai_decision_audit enable row level security;
create policy ai_audit_service on ai_decision_audit for all to service_role using (true) with check (true);

commit;
