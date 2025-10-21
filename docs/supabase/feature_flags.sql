-- Feature Flags schema (v1)
-- Location: docs/supabase/feature_flags.sql

create table if not exists public.feature_flags (
  flag_key text primary key,
  default_on boolean not null default false,
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.org_feature_flags (
  org_id uuid not null,
  flag_key text not null references public.feature_flags(flag_key) on delete cascade,
  enabled boolean not null,
  updated_at timestamptz not null default now(),
  primary key (org_id, flag_key)
);

-- Suggested bootstrap flags
insert into public.feature_flags(flag_key, default_on, description)
values
  ('compare_v1', true, 'Enable compare/save UI'),
  ('alerts_v2', false, 'Next-gen alerts with quiet hours and caps'),
  ('ai_cost_controls', true, 'Admin usage panel and cost controls'),
  ('status_page', true, 'Show status banner and status page link'),
  ('offline_queue_v1', false, 'Offline queue and replay for writes')
on conflict (flag_key) do nothing;
