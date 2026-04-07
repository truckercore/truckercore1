begin;

-- Core prediction storage (idempotent)
create table if not exists public.ai_predictions (
  id uuid primary key default gen_random_uuid(),
  org_id uuid null,
  module text not null,                            -- 'eta' | 'match' | 'fraud'
  subject_id text not null,                        -- e.g., load_id, leg_id, transaction_id
  features jsonb not null,                         -- input feature vector (sanitized)
  prediction jsonb not null,                       -- model output (e.g., {"eta_unix":..., "score":0.82})
  actual jsonb null,                               -- ground truth later (e.g., {"arrived_unix":...,"label":1})
  error jsonb null,                                -- computed: {"mae":..., "rmse":...} or {"abs_sec":...}
  model_version text not null,
  inference_ms int null,
  created_at timestamptz not null default now(),
  unique (module, subject_id, model_version)       -- idempotency per version
);

create index if not exists idx_ai_predictions_module_subj on public.ai_predictions (module, subject_id);
create index if not exists idx_ai_predictions_org_time on public.ai_predictions (org_id, created_at desc);

alter table public.ai_predictions enable row level security;

-- Read policy: org-scoped reads; allow null org rows to be read by any authenticated user
create policy ai_pred_read_org on public.ai_predictions
  for select to authenticated using (
    org_id is null or org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','')
  );

commit;
