-- docs/ci/SECDEF_CHECKS.sql
-- Purpose: CI guard to verify SECURITY DEFINER functions set an explicit search_path
--          and avoid dynamic SQL (EXECUTE) unless explicitly allow‑listed.
-- Usage: psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f docs/ci/SECDEF_CHECKS.sql

-- 1) Collect SECURITY DEFINER functions in public schema
with f as (
  select
    n.nspname as schema,
    p.proname as name,
    p.oid as oid,
    pg_get_functiondef(p.oid) as def,
    p.prosecdef as is_definer
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prosecdef = true
)
-- 1a) Fail if any SECURITY DEFINER function lacks an explicit search_path=public
select case when count(*) > 0 then
  (select raise_exception('SECDEF function missing "set search_path=public" — ' || string_agg(schema||'.'||name, ', ')))
else 0 end
from (
  select 1
  from f
  where def not ilike '%SET search_path=public%'
) q;

-- 2) Forbid EXECUTE in SECURITY DEFINER functions except allowlist
--    Adjust allowlist below to include vetted dynamic SQL helpers.
create temp table if not exists _secdef_allowlist(name text primary key);
insert into _secdef_allowlist(name) values
  ('ensure_loads_partition'),
  ('ensure_geofence_partition'),
  ('refresh_promo_roi'),
  ('purge_billing_logs'),
  ('weekly_geo_maintenance')
  on conflict do nothing;

select case when count(*) > 0 then
  (select raise_exception('SECDEF function uses EXECUTE and is not allow‑listed — ' || string_agg(schema||'.'||name, ', ')))
else 0 end
from (
  select schema, name
  from f
  where def ~* '\mEXECUTE\M'
    and name not in (select name from _secdef_allowlist)
) offenders;

-- Helper to raise errors in SQL scripts
create or replace function public.raise_exception(msg text) returns int language plpgsql as $$
begin
  raise exception '%', msg;
  return 1;
end; $$;