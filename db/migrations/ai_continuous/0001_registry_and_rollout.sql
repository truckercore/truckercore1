begin;

create table if not exists ai_models (
  id uuid primary key default gen_random_uuid(),
  key text unique not null,
  owner text not null default 'ai',
  created_at timestamptz default now()
);

create table if not exists ai_model_versions (
  id uuid primary key default gen_random_uuid(),
  model_id uuid not null references ai_models(id) on delete cascade,
  version text not null,
  artifact_url text not null,
  framework text not null default 'http',
  status text not null check (status in ('shadow','canary','active','retired')),
  metrics jsonb not null default '{}'::jsonb,
  created_at timestamptz default now(),
  unique (model_id, version)
);

create table if not exists ai_rollouts (
  id uuid primary key default gen_random_uuid(),
  model_id uuid not null references ai_models(id) on delete cascade,
  strategy text not null check (strategy in ('single','canary','ab','shadow')),
  active_version_id uuid references ai_model_versions(id) on delete set null,
  control_version_id uuid references ai_model_versions(id) on delete set null,
  candidate_version_id uuid references ai_model_versions(id) on delete set null,
  version_a_id uuid references ai_model_versions(id) on delete set null,
  version_b_id uuid references ai_model_versions(id) on delete set null,
  canary_pct int check (canary_pct between 0 and 100),
  split_pct int check (split_pct between 0 and 100),
  updated_at timestamptz default now(),
  unique (model_id)
);

create table if not exists ai_inference_events (
  id bigserial primary key,
  model_key text not null,
  model_version_id uuid references ai_model_versions(id) on delete set null,
  correlation_id uuid not null default gen_random_uuid(),
  user_id uuid,
  features jsonb not null,
  prediction jsonb not null,
  shadow_prediction jsonb,
  created_at timestamptz default now()
);
create index if not exists idx_ai_inf_model_time on ai_inference_events (model_key, created_at desc);
create index if not exists idx_ai_inf_correlation on ai_inference_events (correlation_id);

create table if not exists ai_feedback_events (
  id bigserial primary key,
  correlation_id uuid not null,
  actual jsonb not null,
  created_at timestamptz default now()
);
create index if not exists idx_ai_fb_corr on ai_feedback_events (correlation_id);

create table if not exists ai_drift_snapshots (
  id bigserial primary key,
  model_key text not null,
  window_start timestamptz not null,
  window_end timestamptz not null,
  stats jsonb not null,
  created_at timestamptz default now()
);

create type if not exists ai_job_status as enum ('queued','running','succeeded','failed','canceled');
create table if not exists ai_training_jobs (
  id uuid primary key default gen_random_uuid(),
  model_key text not null,
  job_kind text not null check (job_kind in ('retrain','online_update')),
  status ai_job_status not null default 'queued',
  params jsonb not null default '{}'::jsonb,
  result jsonb,
  created_at timestamptz default now(),
  started_at timestamptz,
  finished_at timestamptz
);
create index if not exists idx_ai_jobs_model_time on ai_training_jobs (model_key, created_at desc);

create table if not exists ai_accuracy_rollups (
  id bigserial primary key,
  model_key text not null,
  model_version_id uuid,
  window_start timestamptz not null,
  window_end timestamptz not null,
  metrics jsonb not null,
  created_at timestamptz default now()
);

alter table ai_inference_events enable row level security;
alter table ai_feedback_events  enable row level security;
alter table ai_accuracy_rollups enable row level security;
alter table ai_drift_snapshots  enable row level security;
alter table ai_models           enable row level security;
alter table ai_model_versions   enable row level security;
alter table ai_rollouts         enable row level security;
alter table ai_training_jobs    enable row level security;

create policy ai_agg_public_read on ai_accuracy_rollups for select using (true);
create policy ai_drift_public_read on ai_drift_snapshots for select using (true);
create policy ai_models_public_read on ai_models for select using (true);
create policy ai_versions_public_read on ai_model_versions for select using (true);
create policy ai_rollouts_public_read on ai_rollouts for select using (true);

create policy ai_raw_service on ai_inference_events for all to service_role using (true) with check (true);
create policy ai_fb_service  on ai_feedback_events  for all to service_role using (true) with check (true);
create policy ai_jobs_service on ai_training_jobs   for all to service_role using (true) with check (true);

grant select on ai_accuracy_rollups, ai_drift_snapshots, ai_models, ai_model_versions, ai_rollouts to anon, authenticated;
grant select, insert, update, delete on ai_inference_events, ai_feedback_events, ai_training_jobs to service_role;

create or replace function ai_get_serving_version(p_model_key text, p_user_id uuid default null)
returns uuid
language plpgsql
security definer
as $$
declare
  m_id uuid;
  strat text;
  v_active uuid; v_ctrl uuid; v_cand uuid; v_a uuid; v_b uuid;
  pct int; choose int;
begin
  select id into m_id from ai_models where key = p_model_key;
  if m_id is null then raise exception 'unknown model key %', p_model_key; end if;

  select strategy, active_version_id, control_version_id, candidate_version_id, version_a_id, version_b_id, coalesce(canary_pct, split_pct, 0)
  into strat, v_active, v_ctrl, v_cand, v_a, v_b, pct
  from ai_rollouts where model_id = m_id;

  if strat is null or strat = 'single' then
    return v_active;
  elsif strat = 'canary' then
    choose := (abs(('x'||substr(encode(digest(coalesce(p_user_id::text, gen_random_uuid()::text), 'sha1'), 'hex'),1,8))::bit(32)::int) % 100);
    if choose < pct then return v_cand; else return v_ctrl; end if;
  elsif strat = 'ab' then
    choose := (abs(('x'||substr(encode(digest(coalesce(p_user_id::text, gen_random_uuid()::text), 'sha1'), 'hex'),1,8))::bit(32)::int) % 100);
    if choose < pct then return v_a; else return v_b; end if;
  elsif strat = 'shadow' then
    return v_active;
  else
    return v_active;
  end if;
end;
$$;

comment on function ai_get_serving_version(text, uuid) is 'Pick a version per rollout (single/canary/ab/shadow).';

commit;
