-- 20250924_runbook_artifacts.sql
-- Purpose: Runbook artifacts schema (runs, steps, metrics), RLS, KPI views, and ingest RPC.
-- Safe to re-run (idempotent) in Supabase/Postgres.

-- 1) Artifacts: runs and steps
create table if not exists public.runbook_runs (
  id uuid primary key default gen_random_uuid(),
  org_id uuid null,
  git_sha text null,
  report_version text not null default '1.0',
  generated_at_utc timestamptz not null,
  timezone text not null,
  project_url text null,
  flags jsonb not null default '{}'::jsonb,
  summary jsonb not null,
  filename_txt text not null,
  filename_json text not null,
  created_at timestamptz not null default now()
);
create index if not exists idx_runbook_runs_time on public.runbook_runs (created_at desc);
alter table public.runbook_runs enable row level security;
create policy if not exists runbook_runs_read_org on public.runbook_runs
for select to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
grant select on public.runbook_runs to authenticated;

create table if not exists public.runbook_steps (
  id bigserial primary key,
  run_id uuid not null references public.runbook_runs(id) on delete cascade,
  step_index int not null,
  name text not null,
  status text not null check (status in ('OK','FAIL','SKIP')),
  started_at_utc timestamptz not null,
  ended_at_utc timestamptz not null,
  duration_ms bigint not null check (duration_ms >= 0),
  cmd text null,
  stdout_tail text null,
  stderr_tail text null,
  remediation_hint text null,
  created_at timestamptz not null default now()
);
create index if not exists idx_runbook_steps_run on public.runbook_steps (run_id, step_index);
alter table public.runbook_steps enable row level security;
create policy if not exists runbook_steps_read_org on public.runbook_steps
for select to authenticated
using (
  exists (
    select 1 from public.runbook_runs r
    where r.id = runbook_steps.run_id
      and r.org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','')
  )
);
grant select on public.runbook_steps to authenticated;

-- 2) Observability: counters & log trimming metadata
create table if not exists public.runbook_metrics (
  id bigserial primary key,
  run_id uuid not null references public.runbook_runs(id) on delete cascade,
  attempts int not null default 0,
  failures int not null default 0,
  retries int not null default 0,
  http_4xx int not null default 0,
  http_5xx int not null default 0,
  truncated_stdout bool not null default false,
  truncated_stderr bool not null default false,
  created_at timestamptz not null default now()
);
create index if not exists idx_runbook_metrics_run on public.runbook_metrics (run_id);
alter table public.runbook_metrics enable row level security;
create policy if not exists runbook_metrics_read_org on public.runbook_metrics
for select to authenticated
using (
  exists (
    select 1 from public.runbook_runs r
    where r.id = runbook_metrics.run_id
      and r.org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','')
  )
);
grant select on public.runbook_metrics to authenticated;

-- 3) Helper to store deterministic TZ (optional)
create or replace function public.fn_local_tz_now(p_tz text)
returns timestamptz language sql immutable as $$
  (timezone(p_tz, now()) at time zone 'UTC')
$$;

-- 4) Views for KPIs
create or replace view public.v_runbook_daily as
select
  date_trunc('day', created_at) as day,
  count(*) as runs,
  sum( (summary->>'ok')::int ) as steps_ok,
  sum( (summary->>'fail')::int ) as steps_fail,
  avg( (summary->>'duration_ms')::bigint )::bigint as avg_duration_ms,
  avg( (summary->>'exit_code')::int )::int as avg_exit_code
from public.runbook_runs
group by 1
order by 1 desc;

create or replace view public.v_runbook_failures as
select
  r.id as run_id,
  r.created_at,
  s.step_index,
  s.name,
  s.status,
  s.duration_ms,
  s.remediation_hint
from public.runbook_runs r
join public.runbook_steps s on s.run_id = r.id
where s.status = 'FAIL'
order by r.created_at desc, s.step_index;

alter view public.v_runbook_daily owner to postgres;
alter view public.v_runbook_failures owner to postgres;
grant select on public.v_runbook_daily, public.v_runbook_failures to authenticated;

-- Optional summary materialization view
create or replace view public.v_runbook_summary as
select
  r.id as run_id,
  r.created_at,
  (r.summary->>'ok')::int as ok,
  (r.summary->>'fail')::int as fail,
  (r.summary->>'duration_ms')::bigint as duration_ms,
  (r.summary->>'exit_code')::int as exit_code,
  m.attempts, m.failures, m.retries, m.http_4xx, m.http_5xx,
  m.truncated_stdout, m.truncated_stderr
from public.runbook_runs r
left join public.runbook_metrics m on m.run_id = r.id;
grant select on public.v_runbook_summary to authenticated;

-- 5) Ingest RPC (service-role only)
create or replace function public.fn_runbook_ingest(
  p_run jsonb,
  p_steps jsonb,
  p_org_id uuid default null
) returns uuid
language plpgsql
security definer
as $$
declare v_run_id uuid;
begin
  insert into public.runbook_runs(
    id, org_id, git_sha, report_version, generated_at_utc, timezone,
    project_url, flags, summary, filename_txt, filename_json
  ) values (
    gen_random_uuid(),
    p_org_id,
    p_run->>'git_sha',
    coalesce(p_run->>'report_version','1.0'),
    (p_run->>'generated_at')::timestamptz,
    p_run->>'timezone',
    p_run->>'project_url',
    coalesce(p_run->'flags','{}'::jsonb),
    p_run->'summary',
    coalesce(p_run->>'filename_txt',''),
    coalesce(p_run->>'filename_json','')
  ) returning id into v_run_id;

  insert into public.runbook_steps(
    run_id, step_index, name, status, started_at_utc, ended_at_utc, duration_ms, cmd, stdout_tail, stderr_tail, remediation_hint
  )
  select v_run_id,
         (s->>'id')::int,
         s->>'name',
         s->>'status',
         (s->>'started_at')::timestamptz,
         (s->>'ended_at')::timestamptz,
         (s->>'duration_ms')::bigint,
         s->>'cmd',
         s->>'stdout_tail',
         s->>'stderr_tail',
         s->>'remediation_hint'
  from jsonb_array_elements(p_steps) as s;

  return v_run_id;
end $$;

revoke all on function public.fn_runbook_ingest(jsonb,jsonb,uuid) from public, anon, authenticated;
grant execute on function public.fn_runbook_ingest(jsonb,jsonb,uuid) to service_role;
