-- Ensure every entitlements change has a corresponding audit entry within 5s
-- Assumes audit_log has (entity='entitlements', entity_id, created_at)
create or replace view public.v_entitlements_audit_coverage as
select
  e.id as entitlement_id,
  e.feature_key,
  coalesce(e.updated_at, e.starts_at) as updated_at,
  a.id as audit_id,
  a.created_at as audit_at,
  a.actor_user as audit_actor
from public.entitlements e
left join public.audit_log a
  on a.entity = 'entitlements'
 and a.entity_id = e.id::text
 and a.created_at between (coalesce(e.updated_at, e.starts_at) - interval '1 second')
                      and (coalesce(e.updated_at, e.starts_at) + interval '5 second');
