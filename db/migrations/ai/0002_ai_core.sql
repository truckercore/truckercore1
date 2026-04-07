begin;

-- 1) Predictions (store inputs/outputs for eval)
create table if not exists public.ai_predictions (
  id uuid primary key default gen_random_uuid(),
  org_id uuid null,
  module text not null check (module in ('eta','match','fraud')),
  subject_id text not null,                 -- e.g., trip_id/load_id/txn_id
  features jsonb not null,                  -- redacted feature vector
  prediction jsonb not null,                -- {eta_utc:..., score:..., label:...}
  actual jsonb null,                        -- filled when outcome known
  error numeric null,                       -- e.g., abs error minutes or |y - yhat|
  created_at timestamptz not null default now(),
  actual_at timestamptz null
);
create index if not exists idx_ai_pred_module_time on public.ai_predictions (module, created_at desc);
alter table public.ai_predictions enable row level security;
create policy ai_predictions_read_org on public.ai_predictions
for select to authenticated
using (org_id is null or org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

-- 2) Metrics (MAE/RMSE/precision/recall/F1)
create table if not exists public.ai_metrics (
  id bigserial primary key,
  module text not null,
  metric text not null,
  value numeric not null,
  dims jsonb not null default '{}'::jsonb,
  created_at timestamptz default now()
);
create index if not exists idx_ai_metrics_mod_time on public.ai_metrics (module, created_at desc);
alter table public.ai_metrics enable row level security;
create policy ai_metrics_read_all on public.ai_metrics for select to authenticated using (true);

-- 3) Drift logging (PSI per feature)
create table if not exists public.ai_drift (
  id bigserial primary key,
  module text not null,
  feature text not null,
  psi numeric not null,
  train_snapshot jsonb null,    -- e.g., histogram/bin edges
  live_snapshot jsonb null,
  created_at timestamptz default now()
);
create index if not exists idx_ai_drift_mod_feature_time on public.ai_drift (module, feature, created_at desc);
alter table public.ai_drift enable row level security;
create policy ai_drift_read_all on public.ai_drift for select to authenticated using (true);

-- 4) Training feature summaries (for drift baselines)
create table if not exists public.ai_feature_summaries (
  id uuid primary key default gen_random_uuid(),
  module text not null,
  version text not null,            -- model version/tag
  summary jsonb not null,           -- {feature: {bins:[...], dist:[...], mean:..., var:...}, ...}
  created_at timestamptz default now(),
  unique (module, version)
);
alter table public.ai_feature_summaries enable row level security;
create policy ai_feat_read_all on public.ai_feature_summaries for select to authenticated using (true);

-- 5) ROI logging
create table if not exists public.ai_roi (
  id bigserial primary key,
  org_id uuid not null,
  module text not null,
  estimated_savings_usd numeric not null,
  period_start date,
  period_end date,
  dims jsonb not null default '{}'::jsonb,
  created_at timestamptz default now()
);
create index if not exists idx_ai_roi_org_mod_time on public.ai_roi (org_id, module, created_at desc);
alter table public.ai_roi enable row level security;
create policy ai_roi_read_org on public.ai_roi
for select to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

commit;
