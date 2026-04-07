-- 20250928_006_inspection_locale.sql
-- Inspection sessions, safety acks (with locale), interpreter logs, and locale KPI scaffold.

-- Ensure driver_profiles has locale column
alter table if exists public.driver_profiles
  add column if not exists locale text;

-- Inspection sessions --------------------------------------------------------
create table if not exists public.inspection_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id),
  started_at timestamptz not null default now()
);
alter table public.inspection_sessions enable row level security;

do $$ begin
  perform 1 from pg_policies where schemaname = 'public' and tablename = 'inspection_sessions' and policyname = 'driver can insert own session';
  if not found then
    create policy "driver can insert own session"
      on public.inspection_sessions for insert to authenticated
      with check (auth.uid() = user_id);
  end if;
end $$;

-- Safety acknowledgments -----------------------------------------------------
create table if not exists public.safety_acks (
  id bigserial primary key,
  kind text not null,
  locale text,
  occurred_at timestamptz not null default now(),
  org_id uuid
);
alter table public.safety_acks enable row level security;

do $$ begin
  perform 1 from pg_policies where schemaname = 'public' and tablename = 'safety_acks' and policyname = 'allow insert';
  if not found then
    create policy "allow insert" on public.safety_acks for insert to authenticated with check (true);
  end if;
end $$;

-- Locale KPI materialization (hourly source) --------------------------------
create or replace view public.v_kpi_locale_hour as
select
  date_trunc('day', occurred_at) as day,
  locale,
  count(*) filter (where kind is not null) as acks_count
from public.safety_acks
group by 1,2;

-- Locale KPI daily table (separate from other KPI tables to avoid conflicts)
create table if not exists public.kpi_locale_daily (
  day date not null,
  locale text,
  org_id uuid,
  corridor_id uuid,
  acks_count integer not null default 0,
  ack_p50_ms integer,
  ack_p95_ms integer,
  near_miss_count integer not null default 0,
  primary key (day, locale, org_id, corridor_id)
);

-- Interpreter Call Detail Records -------------------------------------------
create table if not exists public.interpreter_calls (
  room_id uuid primary key,
  trip_id uuid,
  vendor_session_id text,
  status text not null default 'created',
  created_at timestamptz not null default now(),
  ended_at timestamptz
);
alter table public.interpreter_calls enable row level security;

-- Service-only insert policy (explicit; service_role bypasses RLS anyway)
do $$ begin
  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='interpreter_calls' and policyname='ins-only'
  ) then
    create policy "ins-only" on public.interpreter_calls for insert to service_role with check (true);
  end if;
end $$;
