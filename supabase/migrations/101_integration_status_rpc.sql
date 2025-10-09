-- 101_integration_status_rpc.sql
-- Idempotent helper for the admin UI

create or replace function integration_status_for_org(p_org uuid)
returns table(provider text, connected boolean, external_account_id text)
language sql stable as $$
  select ip.key,
         (ic.id is not null) as connected,
         ic.external_account_id
  from integration_providers ip
  left join integration_connections ic
    on ic.provider = ip.key and ic.org_id = p_org
  order by ip.key;
$$;

-- Restrictive grants: browser should not call this directly
revoke all on function integration_status_for_org(uuid) from public;
grant execute on function integration_status_for_org(uuid) to service_role;
