-- docs/sql/secdef_inventory.sql
create or replace view public.v_security_definer_inventory as
select
  n.nspname   as schema,
  p.proname   as function,
  pg_get_function_identity_arguments(p.oid) as args,
  p.prosecdef as security_definer,
  regexp_replace(pg_get_functiondef(p.oid), E'\\s+', ' ', 'g') as ddl,
  (pg_get_functiondef(p.oid) ilike '% set search_path = public %') as has_pinned_search_path,
  (pg_get_functiondef(p.oid) ilike '%auth.uid()%'
    or pg_get_functiondef(p.oid) ilike '%auth.jwt()%') as uses_auth_claims
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname='public' and p.prosecdef = true;
