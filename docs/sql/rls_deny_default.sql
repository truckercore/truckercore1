create or replace view public.v_rls_deny_default as
select c.relname as table_name
from pg_class c
join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public'
  and c.relkind='r'
  and c.relrowsecurity
  and not exists (
    select 1 from pg_policies p
    where p.schemaname='public' and p.tablename=c.relname and p.cmd in ('select','all')
  );
-- Alert if any rows appear in v_rls_deny_default
