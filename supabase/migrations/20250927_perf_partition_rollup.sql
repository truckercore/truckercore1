-- Migration: Performance indexes, optional partitioning, and rollup scaffolding
-- Date: 2025-09-27

-- 1.1 Hot-path composite indexes (idempotent)
create index if not exists idx_behavior_events_org_user_time
  on public.behavior_events (org_id, user_id, occurred_at desc);

create index if not exists idx_behavior_events_org_type_time
  on public.behavior_events (org_id, event_type, occurred_at desc);

create index if not exists idx_suggestions_log_user_updated
  on public.suggestions_log (user_id, updated_at desc);

create index if not exists idx_suggestions_log_org_type_updated
  on public.suggestions_log (org_id, suggestion_type, updated_at desc);

-- Our schema uses suggestion_json (not suggested_items); index that
create index if not exists gin_suggestions_log_suggestion_json
  on public.suggestions_log using gin (suggestion_json jsonb_path_ops);

-- 1.2 Declarative monthly partitioning (guarded)
-- NOTE: PostgreSQL does not support converting a non-empty table directly to partitioned.
-- We only convert if the table is empty and not already partitioned.

-- behavior_events by occurred_at
do $$
begin
  if not exists (
    select 1 from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'behavior_events' and c.relkind = 'p'
  ) then
    -- Only attempt if table exists and is empty
    if exists (select 1 from information_schema.tables where table_schema='public' and table_name='behavior_events')
       and not exists (select 1 from public.behavior_events limit 1)
    then
      execute 'alter table public.behavior_events partition by range (occurred_at)';
    else
      raise notice 'Skipping partitioning of behavior_events (non-empty or already partitioned)';
    end if;
  end if;
end$$;

-- suggestions_log by updated_at
-- Ensure updated_at exists (added by prior migration); if not, add now
alter table public.suggestions_log
  add column if not exists updated_at timestamptz not null default now();

-- Touch trigger (idempotent) to keep updated_at fresh
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;$$;

drop trigger if exists trg_suggestions_log_touch on public.suggestions_log;
create trigger trg_suggestions_log_touch
before update on public.suggestions_log
for each row execute function public.touch_updated_at();

-- Guarded partitioning for suggestions_log
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relname = 'suggestions_log' AND c.relkind = 'p'
  ) THEN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='suggestions_log')
       AND NOT EXISTS (SELECT 1 FROM public.suggestions_log LIMIT 1)
    THEN
      EXECUTE 'ALTER TABLE public.suggestions_log PARTITION BY RANGE (updated_at)';
    ELSE
      RAISE NOTICE 'Skipping partitioning of suggestions_log (non-empty or already partitioned)';
    END IF;
  END IF;
END$$;

-- Helper to create monthly partitions
create or replace function public.create_month_partition(
  base_table regclass,
  y int, m int,
  col text
) returns void language plpgsql as $$
declare
  start_ts timestamptz := make_timestamptz(y, m, 1, 0, 0, 0, 'UTC');
  end_ts   timestamptz := (start_ts + interval '1 month');
  partname text := format('%s_%s_%s', base_table::text, to_char(start_ts,'YYYY'), to_char(start_ts,'MM'));
begin
  execute format('create table if not exists %I partition of %s for values from (%L) to (%L);',
                 partname, base_table::text, start_ts, end_ts);
  -- Optional: local index
  execute format('create index if not exists %I on %I (org_id, user_id, %I desc);',
                 partname||'_org_user_time', partname, col);
end$$;

-- Seed partitions for past 6 months and next 3 months (only if parent is partitioned)
DO $$
DECLARE y int; m int; dt date; is_part boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname='public' AND c.relname='behavior_events' AND c.relkind='p') INTO is_part;
  IF is_part THEN
    FOR dt IN SELECT (date_trunc('month', now()) - i*interval '1 month')::date FROM generate_series(0,5) i LOOP
      y := EXTRACT(YEAR FROM dt); m := EXTRACT(MONTH FROM dt);
      PERFORM public.create_month_partition('public.behavior_events', y, m, 'occurred_at');
    END LOOP;
    FOR dt IN SELECT (date_trunc('month', now()) + i*interval '1 month')::date FROM generate_series(1,3) i LOOP
      y := EXTRACT(YEAR FROM dt); m := EXTRACT(MONTH FROM dt);
      PERFORM public.create_month_partition('public.behavior_events', y, m, 'occurred_at');
    END LOOP;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname='public' AND c.relname='suggestions_log' AND c.relkind='p') INTO is_part;
  IF is_part THEN
    FOR dt IN SELECT (date_trunc('month', now()) - i*interval '1 month')::date FROM generate_series(0,5) i LOOP
      y := EXTRACT(YEAR FROM dt); m := EXTRACT(MONTH FROM dt);
      PERFORM public.create_month_partition('public.suggestions_log', y, m, 'updated_at');
    END LOOP;
    FOR dt IN SELECT (date_trunc('month', now()) + i*interval '1 month')::date FROM generate_series(1,3) i LOOP
      y := EXTRACT(YEAR FROM dt); m := EXTRACT(MONTH FROM dt);
      PERFORM public.create_month_partition('public.suggestions_log', y, m, 'updated_at');
    END LOOP;
  END IF;
END$$;

-- 1.3 Retention policy (raw 180d, aggregate older)
create table if not exists public.behavior_events_agg (
  org_id uuid not null,
  bucket_date date not null,
  event_type text not null,
  cnt bigint not null,
  primary key (org_id, bucket_date, event_type)
);

create table if not exists public.suggestions_log_agg (
  org_id uuid not null,
  bucket_date date not null,
  suggestion_type text not null,
  accepted_cnt bigint not null default 0,
  shown_cnt bigint not null default 0,
  ctr numeric not null default 0,
  primary key (org_id, bucket_date, suggestion_type)
);

create or replace function public.rollup_old_raw()
returns void language plpgsql as $$
begin
  -- behavior_events daily rollup for rows older than 180d
  insert into public.behavior_events_agg (org_id, bucket_date, event_type, cnt)
  select org_id, occurred_at::date as bucket_date, event_type, count(*)
  from public.behavior_events
  where occurred_at < now() - interval '180 days'
  group by 1,2,3
  on conflict (org_id, bucket_date, event_type) do update
  set cnt = excluded.cnt;

  -- suggestions_log daily rollup older than 180d
  -- Our schema uses accepted boolean and updated_at
  insert into public.suggestions_log_agg (org_id, bucket_date, suggestion_type, accepted_cnt, shown_cnt, ctr)
  select org_id,
         updated_at::date as bucket_date,
         coalesce(suggestion_type, 'default') as suggestion_type,
         sum(case when accepted then 1 else 0 end) as accepted_cnt,
         count(*) as shown_cnt,
         case when count(*) = 0 then 0 else sum(case when accepted then 1 else 0 end)::numeric / count(*) end as ctr
  from public.suggestions_log
  where updated_at < now() - interval '180 days'
  group by 1,2,3
  on conflict (org_id, bucket_date, suggestion_type) do update
  set accepted_cnt = excluded.accepted_cnt,
      shown_cnt = excluded.shown_cnt,
      ctr = excluded.ctr;

  -- Then delete raw older than 180d
  delete from public.behavior_events where occurred_at < now() - interval '180 days';
  delete from public.suggestions_log where updated_at < now() - interval '180 days';
end$$;
