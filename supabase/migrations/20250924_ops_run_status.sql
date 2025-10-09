-- 20250924_ops_run_status.sql
-- Purpose: Track nightly refresh runs and expose a simple status table for Day-0→Day-30 Ops Plan.
-- Safe to re-run.

-- Nightly refresh status (last-run summary)
create table if not exists public.nightly_refresh_status (
  job_name text primary key,
  last_run_at timestamptz not null default now(),
  rowcount int
);
create index if not exists nrs_last_run_idx on public.nightly_refresh_status (last_run_at desc);

-- Effectiveness refresh runs history (append-only)
create table if not exists public.refresh_effectiveness_runs (
  id bigserial primary key,
  job_name text not null,
  run_at timestamptz not null default now(),
  row_delta int
);
create index if not exists rer_job_time_idx on public.refresh_effectiveness_runs (job_name, run_at desc);

-- Helper upsert function for status
create or replace function public.fn_nightly_refresh_upsert(
  p_job_name text,
  p_rowcount int
) returns void
language plpgsql
security definer
as $$
begin
  insert into public.nightly_refresh_status(job_name, last_run_at, rowcount)
  values (p_job_name, now(), p_rowcount)
  on conflict (job_name) do update set last_run_at = excluded.last_run_at, rowcount = excluded.rowcount;
end;
$$;

revoke all on function public.fn_nightly_refresh_upsert(text,int) from public;
grant execute on function public.fn_nightly_refresh_upsert(text,int) to service_role;
