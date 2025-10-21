create table if not exists public.tenant_canary (
  tenant_id uuid primary key,
  enabled boolean not null default false
);

create or replace function app.tenant_is_canary()
returns boolean language sql stable as $$
  select coalesce(
    (select enabled from public.tenant_canary where tenant_id = app.current_org_id()),
    false)
$$;
