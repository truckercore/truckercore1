-- Graceful downgrades window for entitlements
alter table if exists public.billing_profiles
  add column if not exists grace_until timestamptz;

-- Example policy: managed by webhook/jobs (documentation only)
-- On first past_due: set grace_until = now() + interval '72 hours'
-- On back to active: update grace_until = null
