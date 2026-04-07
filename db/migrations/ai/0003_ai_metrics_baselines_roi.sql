begin;

-- Accuracy metrics
create table if not exists public.ai_metrics (
  id bigserial primary key,
  org_id uuid null,
  module text not null,                 -- 'eta'|'match'|'fraud'
  metric text not null,                 -- 'mae'|'rmse'|'precision'|'recall'|'f1'|...
  value numeric not null,
  model_version text null,
  dims jsonb not null default '{}'::jsonb, -- e.g., {"bucket":"2025-09-01"}
  created_at timestamptz default now()
);
create index if not exists idx_ai_metrics_mod_time on public.ai_metrics (module, created_at desc);
alter table public.ai_metrics enable row level security;
create policy ai_metrics_read_all on public.ai_metrics for select to authenticated using (true);

-- Operational baselines
create table if not exists public.baseline_ops (
  org_id uuid not null,
  scope text not null check (scope in ('fleet','broker')),
  metric text not null,            -- 'empty_miles_pct','fuel_cost_usd_per_mi','dwell_min','time_to_match_min'
  value numeric not null,
  period_start date not null,
  period_end date not null,
  primary key (org_id, scope, metric, period_start, period_end)
);
alter table public.baseline_ops enable row level security;
create policy baseline_read_org on public.baseline_ops
  for select to authenticated using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

-- ROI logging
create table if not exists public.ai_roi (
  id bigserial primary key,
  org_id uuid not null,
  module text not null,                 -- 'eta'|'match'|'fraud'
  estimated_savings_usd numeric not null,
  period_start date,
  period_end date,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz default now()
);
create index if not exists idx_ai_roi_org_time on public.ai_roi (org_id, created_at desc);
alter table public.ai_roi enable row level security;
create policy ai_roi_read_org on public.ai_roi
  for select to authenticated using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

commit;
