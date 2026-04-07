-- Loads (by pickup date) – adapt if you store a different date column
alter table if exists public.loads detach partition default; -- no-op if not set

-- Convert to partitioned if not already
do $$ begin
  if not exists (
    select 1 from pg_class c join pg_inherits i on i.inhparent = c.oid
    where c.relname = 'loads'
  ) then
    alter table public.loads drop constraint if exists loads_pkey;
    alter table public.loads add column if not exists pickup_date date generated always as (date_trunc('day', now())::date) stored; -- fallback if missing
    alter table public.loads partition by range (pickup_date);
  end if;
end $$;

-- Helper to ensure monthly partition exists
create or replace function public.ensure_loads_partition(month_start date)
returns void language plpgsql as $$
declare
  part_name text := 'loads_' || to_char(month_start, 'YYYYMM');
begin
  execute format('create table if not exists public.%I partition of public.loads for values from (%L) to (%L)',
                 part_name, month_start, (month_start + interval '1 month')::date);
end; $$;

-- Same idea for geofence_events by occurred_at
create or replace function public.ensure_geofence_partition(month_start date)
returns void language plpgsql as $$
declare
  part_name text := 'geofence_events_' || to_char(month_start, 'YYYYMM');
begin
  execute format('create table if not exists public.%I partition of public.geofence_events for values from (%L) to (%L)',
                 part_name, month_start, (month_start + interval '1 month')::date);
end; $$;

-- Prune old partitions
create or replace function public.prune_old_partitions(retain_months int)
returns void language plpgsql security definer set search_path=public as $$
declare cutoff date := date_trunc('month', now())::date - (retain_months || ' months')::interval; r record; begin
  for r in
    select inhrelid::regclass::text as part_name
    from pg_inherits
    join pg_class parent on inhparent = parent.oid and parent.relname in ('loads','geofence_events')
    join pg_class child on inhrelid = child.oid
  loop
    if r.part_name ~ '_(\d{6})$' then
      if to_date(right(r.part_name,6), 'YYYYMM') < cutoff then
        execute format('drop table if exists %s cascade', r.part_name);
      end if;
    end if;
  end loop;
end; $$;
