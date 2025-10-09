-- 20250924_system_events_rollup_and_rls.sql
-- Purpose: Implement system_events base table shape, RLS, rollups (view + optional MV),
-- daily totals union view, freshness and gaps views, prune function (returning bigint),
-- simple dedup trigger, and a unified ops snapshot view.
-- Idempotent and compatible with existing system_events artifacts in this repo.

-- 0) Base table (add columns if table exists)
DO $$
BEGIN
  IF to_regclass('public.system_events') IS NULL THEN
    EXECUTE $$
      create table public.system_events (
        id uuid primary key default gen_random_uuid(),
        org_id uuid not null,
        event_code text not null,
        entity_kind text null,
        entity_id text null,
        payload jsonb not null default '{}'::jsonb,
        occurred_at timestamptz not null default now(),
        created_at timestamptz not null default now()
      )
    $$;
  ELSE
    BEGIN ALTER TABLE public.system_events ADD COLUMN IF NOT EXISTS event_code  text;                 EXCEPTION WHEN others THEN NULL; END;
    BEGIN ALTER TABLE public.system_events ADD COLUMN IF NOT EXISTS entity_kind text;                 EXCEPTION WHEN others THEN NULL; END;
    BEGIN ALTER TABLE public.system_events ADD COLUMN IF NOT EXISTS entity_id   text;                 EXCEPTION WHEN others THEN NULL; END;
    BEGIN ALTER TABLE public.system_events ADD COLUMN IF NOT EXISTS payload     jsonb NOT NULL DEFAULT '{}'::jsonb; EXCEPTION WHEN others THEN NULL; END;
    BEGIN ALTER TABLE public.system_events ADD COLUMN IF NOT EXISTS occurred_at timestamptz NOT NULL DEFAULT now(); EXCEPTION WHEN others THEN NULL; END;
    BEGIN ALTER TABLE public.system_events ADD COLUMN IF NOT EXISTS created_at  timestamptz NOT NULL DEFAULT now(); EXCEPTION WHEN others THEN NULL; END;
  END IF;
END$$;

-- Helpful indexes (idempotent)
create index if not exists idx_system_events_org_time  on public.system_events (org_id, occurred_at desc);
create index if not exists idx_system_events_code_time on public.system_events (event_code, occurred_at desc);
create index if not exists idx_system_events_entity    on public.system_events (entity_kind, entity_id);

-- RLS: org-scoped reads; writes via service role
alter table public.system_events enable row level security;
DROP POLICY IF EXISTS system_events_read_org ON public.system_events;
CREATE POLICY system_events_read_org
ON public.system_events
FOR SELECT
TO authenticated
USING (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

REVOKE INSERT, UPDATE, DELETE ON public.system_events FROM authenticated;

-- 1) Rollup view (non-MV)
create or replace view public.v_system_events_rollup as
select
  date_trunc('day', occurred_at)::date as date,
  org_id,
  event_code,
  count(*) as events
from public.system_events
group by 1,2,3;

-- Optional MV for faster queries (refreshable)
create table if not exists public.mv_guard (id int primary key default 1);
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_matviews WHERE schemaname='public' AND matviewname='mv_system_events_rollup'
  ) THEN
    EXECUTE $$
      create materialized view public.mv_system_events_rollup as
      select date_trunc('day', occurred_at)::date as date, org_id, event_code, count(*) as events
      from public.system_events
      group by 1,2,3
      with no data
    $$;
    EXECUTE 'create index if not exists idx_mv_events_day_org on public.mv_system_events_rollup (date desc, org_id)';
  END IF;
END $$;

-- 2) Daily totals view (last N days; union to prefer MV when populated)
create or replace view public.v_daily_events as
with src as (
  select * from public.mv_system_events_rollup
  union all
  select date_trunc('day', occurred_at)::date as date, org_id, event_code, count(*) as events
  from public.system_events
  where occurred_at >= current_date - interval '7 days'
  group by 1,2,3
)
select date, org_id, sum(events) as events
from src
group by 1,2
order by 1 desc, 2;

-- 3) Freshness view (lag per org and overall)
create or replace view public.system_events_freshness as
select
  coalesce(org_id::text,'ALL') as org_id,
  now() - max(occurred_at) as lag,
  max(occurred_at) as last_event_at
from public.system_events
group by rollup(org_id)
order by lag desc;

-- 4) Gaps view (missing days in window per org) default 30 days
create or replace view public.system_events_gaps as
with params as (select (current_date - interval '30 days')::date as start_day, current_date::date as end_day),
.days as (
  select generate_series((select start_day from params), (select end_day from params), interval '1 day')::date as date
),
orgs as (
  select distinct org_id from public.system_events
),
calendar as (
  select o.org_id, d.date from orgs o cross join days d
),
have as (
  select distinct org_id, date_trunc('day', occurred_at)::date as date
  from public.system_events
)
select c.org_id, c.date as date_missing
from calendar c
left join have h on h.org_id = c.org_id and h.date = c.date
where h.date is null
order by c.date desc;

-- 5) Prune function (retention in days) returning bigint
create or replace function public.prune_system_events(p_days int)
returns bigint
language plpgsql
security definer
as $$
declare v_rows bigint;
begin
  with del as (
    delete from public.system_events
    where occurred_at < now() - make_interval(days => p_days)
    returning 1
  ) select count(*) into v_rows from del;
  -- Optional: reset stats if available (ignore errors)
  begin perform pg_stat_statements_reset(); exception when others then null; end;
  return coalesce(v_rows, 0);
end $$;

revoke all on function public.prune_system_events(int) from public;
grant execute on function public.prune_system_events(int) to service_role;

-- 6) Simple dedup guard: drop identical repeat within 10 seconds for same key
create or replace function public.fn_system_events_dedup()
returns trigger
language plpgsql
as $$
declare v_exists bool;
begin
  select true into v_exists
  from public.system_events
  where org_id = new.org_id
    and coalesce(entity_kind,'') = coalesce(new.entity_kind,'')
    and coalesce(entity_id,'') = coalesce(new.entity_id,'')
    and event_code = new.event_code
    and occurred_at >= new.occurred_at - interval '10 seconds'
  limit 1;

  if v_exists then
    return null; -- ignore duplicate flap
  end if;
  return new;
end $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_system_events_dedup') THEN
    EXECUTE $$
      create trigger trg_system_events_dedup
      before insert on public.system_events
      for each row execute function public.fn_system_events_dedup()$$;
  END IF;
END $$;

-- 7) Unified ops snapshot view
create or replace view public.v_ops_health as
select
  now() as as_of,
  (select max(occurred_at) from public.system_events)           as last_event_at,
  (select max(date) from public.v_system_events_rollup)         as last_rollup_day,
  (select max(date) from public.v_daily_events)                 as last_daily_day,
  (select max(lag) from public.system_events_freshness)         as worst_lag,
  (select count(*) from public.system_events_gaps
     where date_missing >= current_date - interval '7 days')    as gaps_7d;
