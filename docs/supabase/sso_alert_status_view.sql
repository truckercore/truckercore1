-- docs/supabase/sso_alert_status_view.sql
-- Shared status view for SSO health to keep UI badges and alerts consistent.
-- Idempotent: safe to re-run.

-- Requirements:
-- - v_sso_failure_rate_24h view (org_id, attempts_24h, failures_24h, failure_rate_24h)
-- - sso_health table (org_id, idp, last_error_code, last_success_at, last_error_at,
--   canary_consecutive_failures optional, self_check_ok)

create or replace view public.v_sso_health_status as
select
  h.org_id,
  h.idp,
  h.last_success_at,
  h.last_error_at,
  h.last_error_code,
  coalesce(r.attempts_24h, h.attempts_24h) as attempts_24h,
  coalesce(r.failures_24h, h.failures_24h) as failures_24h,
  coalesce(r.failure_rate_24h, case when coalesce(h.attempts_24h,0)=0 then 0 else h.failures_24h::numeric/nullif(h.attempts_24h,0) end) as failure_rate_24h,
  coalesce(h.self_check_ok, true) as self_check_ok,
  coalesce(h.canary_consecutive_failures, 0) as canary_consecutive_failures,
  -- Status computation aligned with alerts:
  -- Red: failure_rate_24h > 10% OR canary_consecutive_failures >= 2 OR last_self_check was not ok
  -- Amber: failure_rate_24h 5–10% OR last_success_at 14–30d OR recent error within 48h
  -- Green: otherwise
  (
    case
      when coalesce(h.canary_consecutive_failures,0) >= 2 then 'red'
      when coalesce(r.failure_rate_24h, 0) > 0.10 then 'red'
      when coalesce(h.self_check_ok,false) = false then 'red'
      when coalesce(r.failure_rate_24h, 0) > 0.05 then 'amber'
      when h.last_success_at is not null and h.last_success_at < now() - interval '14 days' and h.last_success_at >= now() - interval '30 days' then 'amber'
      when h.last_error_at is not null and h.last_error_at >= now() - interval '2 days' then 'amber'
      else 'green'
    end
  ) as status
from public.sso_health h
left join public.v_sso_failure_rate_24h r using (org_id);

-- RLS: view inherits from base tables; ensure base tables have appropriate RLS.
