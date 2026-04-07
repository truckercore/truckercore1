-- 02_feature_flags_seed.sql
-- Seed feature flags and provide guidance for server-side caching/override.

-- Ensure feature flags table exists (from 04_feature_flags_and_usage.sql, but guard here too)
create table if not exists public.org_feature_flags (
  org_id uuid primary key,
  flags jsonb not null default '{}'::jsonb,
  updated_at timestamptz default now()
);

-- Seed global defaults using a special org_id of all-zeros, overridden per org when needed.
-- Consumers should merge per-org flags over these defaults.
insert into public.org_feature_flags(org_id, flags)
values (
  '00000000-0000-0000-0000-000000000000',
  jsonb_build_object(
    'audit_logging', true,
    'enterprise_hardening', false
  )
)
on conflict (org_id) do update set
  flags = excluded.flags,
  updated_at = now();

comment on table public.org_feature_flags is 'Org-scoped feature flags. Use zero-UUID for defaults; merge with per-org overrides.';

-- Retention policy guidance (documentation only in this seed):
--  - Enterprise: retain enterprise_audit_log rows >= 365 days
--  - Lower tiers: retain >= 90 days
-- A weekly purge job should delete old rows by created_at threshold per org subscription tier.
-- Consider using pg_cron or external scheduler calling a SECURITY DEFINER purge function.
