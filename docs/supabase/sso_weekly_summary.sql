-- docs/supabase/sso_weekly_summary.sql
-- Weekly summary view for SSO/SCIM/canary/rotation status. Idempotent.

-- Inputs expected:
-- - public.sso_events (org_id, outcome, error_code, ts)
-- - public.scim_audit (org_id, status, created_count, updated_count, deactivated_count, run_finished_at)
-- - public.rotation_reminders (org_id, kind, last_rotated_at)
-- - public.sso_health (org_id, idp, last_success_at, canary_consecutive_failures)

create or replace view public.v_sso_weekly_summary as
with
sso_agg as (
  select org_id,
         count(*) filter (where outcome='error') as failures_sum,
         count(*) as attempts_sum,
         round(coalesce(count(*) filter (where outcome='error')::numeric / nullif(count(*),0),0), 4) as failure_rate_week,
         max(ts) filter (where outcome='success') as last_sso_success_at,
         max(error_code) filter (where outcome='error') as last_error_code
  from public.sso_events
  where ts >= now() - interval '7 days'
  group by org_id
),
scim as (
  select org_id,
         count(*) filter (where status = 'failed') as scim_failed_runs,
         count(*) filter (where status = 'partial') as scim_partial_runs,
         sum(created_count) as scim_created_sum,
         sum(updated_count) as scim_updated_sum,
         sum(deactivated_count) as scim_deactivated_sum,
         max(run_finished_at) as scim_last_run_at
  from public.scim_audit
  where run_started_at >= now() - interval '7 days'
  group by org_id
),
rotation as (
  select org_id,
         max(last_rotated_at) filter (where kind = 'oidc_client_secret') as last_oidc_rotation,
         max(last_rotated_at) filter (where kind = 'scim_token') as last_scim_rotation,
         bool_or((now() - last_rotated_at) > interval '90 days') as rotation_overdue
  from public.rotation_reminders
  group by org_id
)
select
  coalesce(sso_agg.org_id, scim.org_id, rotation.org_id, sh.org_id) as org_id,
  coalesce(sh.idp, 'unknown') as idp,
  sso_agg.attempts_sum,
  sso_agg.failures_sum,
  sso_agg.failure_rate_week,
  coalesce(sh.canary_consecutive_failures, 0) as canary_consecutive_failures,
  sh.last_success_at as last_canary_success_at,
  sso_agg.last_sso_success_at,
  sso_agg.last_error_code,
  scim.scim_failed_runs,
  scim.scim_partial_runs,
  scim.scim_created_sum,
  scim.scim_updated_sum,
  scim.scim_deactivated_sum,
  scim.scim_last_run_at,
  rotation.last_oidc_rotation,
  rotation.last_scim_rotation,
  rotation.rotation_overdue
from sso_agg
full outer join scim using (org_id)
full outer join rotation using (org_id)
full outer join public.sso_health sh using (org_id)
order by org_id;