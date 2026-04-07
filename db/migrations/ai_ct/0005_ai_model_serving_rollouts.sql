begin;

create table if not exists public.ai_model_serving (
  model_key text primary key,                -- 'eta'|'match'|'fraud'
  live_version_id text not null,
  updated_at timestamptz not null default now()
);

create table if not exists public.ai_model_rollouts (
  id uuid primary key default gen_random_uuid(),
  model_key text not null,
  baseline_version_id text null,
  candidate_version_id text not null,
  status text not null check (status in ('canary','closed')),
  pct int not null check (pct between 1 and 100),
  window_min int not null default 60,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_ai_rollouts_model on public.ai_model_rollouts (model_key, status);

commit;
