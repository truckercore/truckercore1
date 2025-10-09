-- Profile learning job: learning_profiles + job_audit_log + RPC + helper
-- Date: 2025-09-27

-- Extensions (UUID)
create extension if not exists "uuid-ossp";

-- Tables
create table if not exists public.learning_profiles (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade,
  org_id uuid not null,
  learning_data jsonb not null default '{}'::jsonb,
  confidence numeric not null default 0.0,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (user_id, org_id)
);

create table if not exists public.job_audit_log (
  id uuid primary key default uuid_generate_v4(),
  job_name text not null,
  ran_at timestamptz not null default now(),
  status text not null, -- 'starting' | 'completed' | 'failed'
  details jsonb
);

-- RLS
alter table public.learning_profiles enable row level security;
alter table public.job_audit_log enable row level security;

-- Policies
-- Allow owners to view their profiles; admins/managers within same org may view all
drop policy if exists lp_select on public.learning_profiles;
create policy lp_select on public.learning_profiles
for select
using (
  (auth.uid() = user_id)
  or (
    current_setting('request.headers', true)::jsonb ? 'x-app-roles'
    and (
      'admin' = any(string_to_array(coalesce((current_setting('request.headers', true)::jsonb ->> 'x-app-roles'), ''), ','))
      or 'manager' = any(string_to_array(coalesce((current_setting('request.headers', true)::jsonb ->> 'x-app-roles'), ''), ','))
    )
    and coalesce((current_setting('request.headers', true)::jsonb ->> 'x-app-org-id'), '')::uuid = org_id
  )
);

-- Optional: allow users to upsert only their own row (commonly not needed; writes come from service RPC)
drop policy if exists lp_upsert_self on public.learning_profiles;
create policy lp_upsert_self on public.learning_profiles
for insert to authenticated
with check (auth.uid() = user_id)
;

drop policy if exists lp_update_self on public.learning_profiles;
create policy lp_update_self on public.learning_profiles
for update to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id)
;

-- No user access to audit logs (function/service-only)
drop policy if exists jal_read_none on public.job_audit_log;
create policy jal_read_none on public.job_audit_log
for all
using (false)
with check (false)
;

-- RPCs

-- Helper: safe header getter (returns null if header missing)
create or replace function public.http_header(name text)
returns text
language sql
stable
as $$
  select (current_setting('request.headers', true)::jsonb ->> name)
$$;

-- RPC to run nightly learning, SECURITY DEFINER for administrative write access
create or replace function public.run_learning_job()
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_started_id uuid;
  v_updated_count int := 0;
begin
  -- Start audit entry
  insert into public.job_audit_log (job_name, status, details)
  values ('nightly_learning_job', 'starting', jsonb_build_object('invoked_by', coalesce(public.http_header('x-cron-secret'), 'manual')))
  returning id into v_started_id;

  -- Aggregate recent behavior events to a compact learning_data per (user_id, org_id)
  with recent as (
    select
      user_id,
      org_id,
      count(*) as event_count,
      avg((properties ->> 'deadhead_miles')::numeric) filter (where (properties ? 'deadhead_miles')) as avg_deadhead,
      sum(case when (properties ->> 'tolls')::boolean is true then 1 else 0 end) as toll_yes,
      sum(case when (properties ->> 'tolls')::boolean is false then 1 else 0 end) as toll_no
    from public.behavior_events
    where occurred_at >= now() - interval '90 days'
    group by user_id, org_id
  ),
  ranked as (
    select
      r.user_id,
      r.org_id,
      jsonb_strip_nulls(jsonb_build_object(
        'avg_deadhead_miles', r.avg_deadhead,
        'toll_aversion', case when (r.toll_yes + r.toll_no) > 0
                              then greatest(0, least(1, 1 - (r.toll_yes::numeric / greatest(1, (r.toll_yes + r.toll_no))::numeric)))
                              else 0.5 end,
        'event_count', r.event_count
      )) as learning_data,
      least(1.0, greatest(0.1, (r.event_count::numeric / 200.0)))::numeric as confidence
    from recent r
  )
  insert into public.learning_profiles as lp (user_id, org_id, learning_data, confidence, updated_at)
  select user_id, org_id, learning_data, confidence, now()
  from ranked
  on conflict (user_id, org_id) do update
    set learning_data = excluded.learning_data,
        confidence = excluded.confidence,
        updated_at = now();

  get diagnostics v_updated_count = row_count;

  -- Complete audit
  update public.job_audit_log
  set status = 'completed',
      details = coalesce(details, '{}'::jsonb) || jsonb_build_object(
        'updated', v_updated_count,
        'completed_at', now()
      )
  where id = v_started_id;

  return jsonb_build_object('updated', v_updated_count);
exception when others then
  -- Failure audit
  if v_started_id is null then
    insert into public.job_audit_log (job_name, status, details)
    values ('nightly_learning_job', 'failed', jsonb_build_object('error', SQLERRM, 'when', now()));
  else
    update public.job_audit_log
    set status = 'failed',
        details = coalesce(details, '{}'::jsonb) || jsonb_build_object('error', SQLERRM, 'when', now())
    where id = v_started_id;
  end if;
  raise;
end;
$$;

-- Grants: allow service role to execute administrative RPC
grant execute on function public.run_learning_job() to service_role;
