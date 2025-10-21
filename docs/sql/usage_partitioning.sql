-- Hot partitioning + retention (keep usage fast forever)
-- Range-partition usage_events by month; prune >12 months (tune as needed)

-- Parent already exists: usage_events(id, org_id, feature_key, user_id, units, at, meta jsonb, ...)
-- Ensure default now() on at
alter table if exists public.usage_events
  alter column at set default now();

-- Create partition for a given month if missing
create or replace function public.usage_part_ensure(p_date date)
returns void language plpgsql as $$
declare
  part text := format('usage_events_%s', to_char(p_date,'YYYYMM'));
begin
  execute format($$
    create table if not exists %I partition of usage_events
    for values from (%L) to (%L)
  $$,
    part,
    date_trunc('month',p_date)::date,
    (date_trunc('month',p_date)+interval '1 month')::date
  );
end $$;

-- Drop partitions older than keep_months (default: 12)
create or replace function public.usage_prune_old_parts(keep_months int default 12)
returns int language plpgsql as $$
declare
  dropped int := 0;
  drop_stmt text;
begin
  for drop_stmt in
    select format('drop table if exists %I cascade', c.relname)
    from pg_inherits i
    join pg_class c on c.oid = i.inhrelid
    join pg_class p on p.oid = i.inhparent
    join pg_namespace n on n.oid = c.relnamespace
    where p.relname = 'usage_events'
      and n.nspname = 'public'
      and c.relname ~ '^usage_events_[0-9]{6}$'
      and to_date(substring(c.relname from '[0-9]{6}$'),'YYYYMM')
          < (date_trunc('month', now()) - make_interval(months=>keep_months))::date
  loop
    execute drop_stmt;
    dropped := dropped + 1;
  end loop;
  return dropped;
end $$;

-- Cron examples:
-- monthly:  select public.usage_part_ensure(now());
-- weekly:   select public.usage_prune_old_parts(12);
