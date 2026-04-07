-- 04_feature_flags_and_usage.sql
-- Organization-scoped feature flags and usage counters

create table if not exists public.org_feature_flags (
  org_id uuid primary key,
  flags jsonb not null default '{}'::jsonb, -- e.g., {"ranker_v1":true,"backhaul_v1":false}
  updated_at timestamptz default now()
);

create table if not exists public.usage_counters (
  id uuid primary key default gen_random_uuid(),
  org_id uuid,
  key text not null,                 -- e.g., 'searches','requests_sent','offers_sent'
  window text not null default 'all',-- e.g., 'all','day','month'
  count bigint not null default 0,
  updated_at timestamptz default now()
);
create index if not exists idx_usage_counters_org_key on public.usage_counters(org_id, key);
