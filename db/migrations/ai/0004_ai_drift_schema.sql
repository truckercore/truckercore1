begin;

-- Feature summaries at train/live time
create table if not exists public.ai_feature_summaries (
  id uuid primary key default gen_random_uuid(),
  module text not null,                 -- 'eta'|'match'|'fraud'
  model_version text not null,
  feature text not null,                -- e.g., 'route_len_mi'
  stats jsonb not null,                 -- {"mean":..., "std":..., "bins":[{"lo":..,"hi":..,"p":..},...]}
  kind text not null default 'train',   -- 'train' or 'live'
  captured_at timestamptz not null default now(),
  unique (module, model_version, feature, kind)
);

-- Drift logs per feature
create table if not exists public.ai_drift (
  id bigserial primary key,
  module text not null,
  model_version text not null,
  feature text not null,
  psi numeric null,
  kl_div numeric null,
  ks_stat numeric null,
  bucket_start timestamptz not null,
  bucket_end timestamptz not null,
  status text not null default 'ok' check (status in ('ok','warn','alert')),
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_ai_drift_mod_time on public.ai_drift (module, created_at desc);

alter table public.ai_feature_summaries enable row level security;
alter table public.ai_drift enable row level security;
create policy ai_drift_read_all on public.ai_feature_summaries for select to authenticated using (true);
create policy ai_drift2_read_all on public.ai_drift for select to authenticated using (true);

commit;
