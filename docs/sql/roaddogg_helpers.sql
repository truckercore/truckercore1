-- roaddogg_helpers.sql
-- Idempotent helpers and predicates for Roaddogg ML package

create extension if not exists "uuid-ossp";

-- Touch updated_at on UPDATE for tables that explicitly attach this trigger
create or replace function set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

-- Convenience predicates (JWT-based)
create or replace function app_org() returns uuid
language sql stable as $$ select nullif(auth.jwt()->>'app_org_id','')::uuid $$;

create or replace function app_role() returns text
language sql stable as $$ select coalesce(auth.jwt()->>'app_role','') $$;

-- Common RLS predicates
create or replace function rls_same_org(org uuid) returns boolean
language sql stable as $$ select app_org() = org $$;

create or replace function is_roaddogg() returns boolean
language sql stable as $$ select (auth.jwt()->>'svc') = 'roaddogg' or app_role() = 'roaddogg_service' $$;
