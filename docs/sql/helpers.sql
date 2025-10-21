-- helpers.sql
-- Helpers (JWT → org/role) + common RLS predicates

create or replace function current_org_id() returns uuid
language sql stable as $$
  select nullif(auth.jwt()->>'app_org_id','')::uuid
$$;

create or replace function current_role() returns text
language sql stable as $$
  select nullif(auth.jwt()->>'app_role','')
$$;

create or replace function is_org_admin() returns boolean
language sql stable as $$
  select coalesce(current_role() in ('admin','fleet_admin','broker_admin','shipper_admin'), false)
$$;

-- Convenience: same-tenant check
create or replace function same_org(p_org uuid) returns boolean
language sql stable as $$
  select p_org = current_org_id()
$$;
