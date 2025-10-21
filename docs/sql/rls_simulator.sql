-- docs/sql/rls_simulator.sql
-- Helper to simulate RLS visibility by injecting JWT claims into the session
-- Safe to rerun; SECURITY DEFINER with pinned search_path

create or replace function public.rls_simulate(
  p_table regclass,
  p_filter text,
  p_claims jsonb
) returns int
language plpgsql
security definer
set search_path=public
as $$
declare
  rv int;
begin
  -- Inject claims for the duration of this transaction
  perform set_config('request.jwt.claims', p_claims::text, true);
  -- Count rows visible under RLS for the provided filter
  execute format('select count(*) from %s where %s', p_table, p_filter) into rv;
  return coalesce(rv, 0);
end $$;

-- Example usages (for local psql):
-- select public.rls_simulate('ownerop_expenses', 'true', '{"app_org_id":"ORG_A","app_roles":["driver"]}');
