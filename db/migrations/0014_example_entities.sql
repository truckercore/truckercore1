-- 0014_example_entities.sql
-- Purpose: example_entities table with constraints, indexes, comments, feature flag, and RLS example.
-- This migration is idempotent and safe to run multiple times.

begin;

-- Core table
create table if not exists public.example_entities (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  name text not null check (length(name) between 3 and 120),
  status text not null default 'active' check (status in ('active','disabled')),
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (org_id, name)
);

-- Index to support org+status filters
create index if not exists idx_example_entities_org_status
  on public.example_entities (org_id, status);

-- Documentation
comment on table public.example_entities is 'Example entities scoped by org with status and metadata';
comment on column public.example_entities.org_id is 'Owning organization (RLS-scope)';
comment on column public.example_entities.meta is 'Arbitrary attributes (validated in app)';

-- Optional audit sink (ensure exists)
create table if not exists public.audit_log (
  id uuid primary key default gen_random_uuid(),
  org_id uuid null,
  actor_user_id uuid null,
  action text not null,
  entity text not null,
  entity_id text not null,
  diff jsonb null,
  created_at timestamptz not null default now()
);

-- Feature flags table (ensure exists) + seed one example flag
create table if not exists public.feature_flags (
  key text primary key,
  enabled boolean not null default false,
  description text not null,
  updated_at timestamptz not null default now()
);
insert into public.feature_flags(key, enabled, description)
values ('FEATURE_EXAMPLE_ENABLED', false, 'Gate example_entities endpoints/UI')
on conflict (key) do nothing;

-- RLS example (optional)
alter table public.example_entities enable row level security;
-- Create policy only if absent
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='public' AND tablename='example_entities' AND policyname='example_entities_read_org'
  ) THEN
    CREATE POLICY example_entities_read_org ON public.example_entities
      FOR SELECT TO authenticated
      USING (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
  END IF;
END$$;

commit;
