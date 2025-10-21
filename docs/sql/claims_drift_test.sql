create or replace function public.rls_claims_drift_check(p_table regclass)
returns boolean
language plpgsql
security definer
set search_path=public
as $$
declare a int; b int;
begin
  a := rls_simulate(p_table, 'true', '{"app_org_id":"ORG_A","app_role":"driver"}');
  b := rls_simulate(p_table, 'true', '{"orgId":"ORG_A","role":"driver"}'); -- wrong keys
  return b = 0; -- must not pass with wrong claim names
end $$;
