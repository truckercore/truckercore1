-- Canonical claim readers (never call auth.jwt() inline in policies)
create schema if not exists app;

create or replace function app.current_org_id() returns uuid
language sql stable as $$
  select ((select auth.jwt())::json ->> 'app_org_id')::uuid
$$;

create or replace function app.current_role() returns text
language sql stable as $$
  select (select auth.jwt())::json ->> 'app_role'
$$;

-- Example policy using the canonical accessor (not raw auth.jwt())
alter table if exists public.loads enable row level security;

drop policy if exists loads_org_isolation on public.loads;
create policy loads_org_isolation on public.loads
  for all
  using (org_id = app.current_org_id())
  with check (org_id = app.current_org_id());
