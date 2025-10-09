-- 20250928_etl_jobs.sql
-- Minimal ETL jobs table for etl-runner function
create table if not exists public.etl_jobs (
  id uuid primary key default gen_random_uuid(),
  org_id uuid,
  provider text not null, -- 'samsara' | 'qbo' | etc.
  payload jsonb not null default '{}'::jsonb,
  status text not null default 'queued', -- queued|processing|ok|error
  error text,
  created_at timestamptz not null default now(),
  processed_at timestamptz
);

create index if not exists etl_jobs_status_idx on public.etl_jobs(status, created_at asc);
