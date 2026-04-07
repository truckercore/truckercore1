-- 907_ci_integration_ledger.sql
-- Minimal CI health ledger for integration runs
create table if not exists public.ci_integration_runs (
  id bigserial primary key,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  branch text not null,
  commit_sha text not null,
  status text not null check (status in ('running','passed','failed')),
  notes text
);

create index if not exists idx_ci_integration_runs_time on public.ci_integration_runs (started_at desc);

-- Simple view for latest status by branch
create or replace view public.v_ci_integration_latest as
select distinct on (branch)
  branch, commit_sha, status, started_at, finished_at, notes
from public.ci_integration_runs
order by branch, started_at desc;
