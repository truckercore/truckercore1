-- 999_enforce_pk_rls_and_checks.sql
-- Guardrails: enforce PK and RLS on new public tables; add sanity checks.

-- 1) Ensure every new public table has a PRIMARY KEY (event trigger)
create or replace function public._enforce_pk()
returns event_trigger language plpgsql as $$
declare obj record;
begin
  for obj in
    select * from pg_event_trigger_ddl_commands()
    where command_tag = 'CREATE TABLE'
  loop
    perform 1
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public'
      and t.relname = obj.object_identity::text::regclass::text
      and c.contype = 'p';
    if not found then
      raise exception 'Table % must have a PRIMARY KEY', obj.object_identity;
    end if;
  end loop;
end $$;

drop event trigger if exists trg_enforce_pk;
create event trigger trg_enforce_pk
  on ddl_command_end
  when tag in ('CREATE TABLE')
  execute procedure public._enforce_pk();

-- 2) Ensure RLS is enabled for every new public table (event trigger)
create or replace function public._enforce_rls()
returns event_trigger language plpgsql as $$
declare obj record;
begin
  for obj in
    select * from pg_event_trigger_ddl_commands()
    where command_tag = 'CREATE TABLE'
  loop
    -- Always enable RLS for new tables
    execute format('alter table %s enable row level security', obj.object_identity);
  end loop;
end $$;

drop event trigger if exists trg_enforce_rls;
create event trigger trg_enforce_rls
  on ddl_command_end
  when tag in ('CREATE TABLE')
  execute procedure public._enforce_rls();

-- 3) Dependencies for validation blocks (create if missing)
-- 3.1 View listing public tables and whether RLS is enabled
create or replace view public.rls_audit as
select
  n.nspname as schema,
  c.relname as table,
  c.relrowsecurity as rls_enabled
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind = 'r'
  and c.relname not like 'pg_%'
  and c.relname not like 'sql_%';

-- 3.2 Heartbeats table to record cron last_seen timestamps
create table if not exists public.cron_heartbeats (
  key text primary key,
  last_seen timestamptz not null default now()
);

-- 4) Defense-in-depth validation blocks
-- 4.1 Fail if any public tables lack RLS
DO $$
DECLARE bad int;
BEGIN
  select count(*) into bad
  from public.rls_audit
  where rls_enabled = false;
  IF bad > 0 THEN
    RAISE EXCEPTION 'RLS disabled on % tables', bad;
  END IF;
END $$;

-- 4.2 Fail if critical cron heartbeats are stale (> 2 hours)
DO $$
DECLARE stale int;
BEGIN
  select count(*) into stale
  from public.cron_heartbeats
  where key in ('notify-alerts','rollup_chunked')
    and (now() - last_seen) > interval '2 hours';
  IF stale > 0 THEN
    RAISE EXCEPTION 'Stale cron heartbeats detected';
  END IF;
END $$;
