-- SECURITY-BARRIER VIEW over risk_corridor_cells with stable quals
-- Backing table expected from previous migration: public.risk_corridor_cells(org_id, cell geometry, alert_count, urgent_count, types jsonb, updated_at)
-- Add observed_at for sort coverage if missing
do $$
begin
  if not exists (
    select 1 from information_schema.columns
      where table_schema = 'public' and table_name = 'risk_corridor_cells' and column_name = 'observed_at'
  ) then
    alter table public.risk_corridor_cells add column observed_at timestamptz not null default now();
    create index if not exists idx_risk_cells_org_observed on public.risk_corridor_cells (org_id, observed_at desc);
  end if;
end$$;

-- Secure view with security_barrier and invoker’s rights
drop view if exists public.risk_corridors_secure cascade;
create view public.risk_corridors_secure
  with (security_barrier = true, security_invoker = true)
as
select
  org_id,
  observed_at,
  alert_count,
  urgent_count,
  types,
  cell
from public.risk_corridor_cells
where
  -- simple, leak-proof quals using built-ins only
  org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','');

-- Make view read-only: no updatable columns through the view
-- PostgreSQL views are read-only unless rules/triggers defined; do not create insert/update rules.
-- RLS-like behavior via security_barrier + WHERE; also clamp PostgREST by default
revoke all on public.risk_corridors_secure from public;
grant select on public.risk_corridors_secure to authenticated, anon;

-- Advisory lock helpers
create or replace function public.job_lock_key(p_fingerprint text)
returns bigint
language sql
stable
as $$
  -- hash to int8; pg_catalog ensured below via search_path set in wrappers
  select ('x'||substr(md5(coalesce(p_fingerprint,'')),1,16))::bit(64)::bigint;
$$;

create or replace function public.try_job_lock(p_fingerprint text)
returns boolean
language plpgsql
security definer
as $$
declare
  got boolean;
begin
  perform set_config('search_path','pg_catalog, public', true);
  select pg_try_advisory_lock(public.job_lock_key(p_fingerprint)) into got;
  return got;
end
$$;
revoke all on function public.try_job_lock(text) from public;
grant execute on function public.try_job_lock(text) to service_role;

create or replace function public.release_job_lock(p_fingerprint text)
returns boolean
language plpgsql
security definer
as $$
declare
  ok boolean;
begin
  perform set_config('search_path','pg_catalog, public', true);
  select pg_advisory_unlock(public.job_lock_key(p_fingerprint)) into ok;
  return ok;
end
$$;
revoke all on function public.release_job_lock(text) from public;
grant execute on function public.release_job_lock(text) to service_role;

create or replace function public.xact_job_lock(p_fingerprint text)
returns boolean
language plpgsql
security definer
as $$
begin
  perform set_config('search_path','pg_catalog, public', true);
  perform pg_advisory_xact_lock(public.job_lock_key(p_fingerprint));
  return true;
end
$$;
revoke all on function public.xact_job_lock(text) from public;
grant execute on function public.xact_job_lock(text) to service_role;

-- CSV Export secure view with computed, immutable export fields
-- We expose corridor data with a stable observed_at to sort
drop view if exists public.v_risk_corridors_export cascade;
create view public.v_risk_corridors_export
  with (security_barrier = true, security_invoker = true)
as
select
  gen_random_uuid() as export_row_id,
  org_id,
  observed_at,
  urgent_count,
  alert_count,
  types,
  st_asgeojson(cell)::jsonb as cell_geojson
from public.risk_corridor_cells
where org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','');
revoke all on public.v_risk_corridors_export from public;
grant select on public.v_risk_corridors_export to authenticated;

-- DLQ table for exports
create table if not exists public.export_dlq (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('risk_corridors_csv')),
  org_id uuid not null,
  payload jsonb not null,
  error text not null,
  created_at timestamptz not null default now(),
  handled boolean not null default false,
  handled_at timestamptz
);
create index if not exists idx_export_dlq_time on public.export_dlq (created_at desc);

-- Async export jobs table
create table if not exists public.export_jobs (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('risk_corridors_csv')),
  org_id uuid not null,
  params jsonb not null,
  status text not null check (status in ('queued','running','completed','failed')),
  artifact_url text,
  error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_export_jobs_org_time on public.export_jobs (org_id, created_at desc);

alter table public.export_dlq enable row level security;
alter table public.export_jobs enable row level security;

-- RLS: org-scoped read/write by authenticated
drop policy if exists export_jobs_rw on public.export_jobs;
create policy export_jobs_rw on public.export_jobs
for all to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''))
with check (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

drop policy if exists export_dlq_read_org on public.export_dlq;
create policy export_dlq_read_org on public.export_dlq
for select to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

-- service role can write DLQ/jobs
grant select, insert, update on public.export_dlq to service_role;
grant select, insert, update on public.export_jobs to service_role;

-- Metrics table
create table if not exists public.metrics_counters (
  name text not null,
  labels jsonb not null default '{}'::jsonb,
  value double precision not null default 0,
  updated_at timestamptz not null default now(),
  primary key (name, labels)
);
grant select, insert, update on public.metrics_counters to service_role;

-- Helper upsert function for counters/histograms (service only)
create or replace function public.metrics_add(p_name text, p_labels jsonb, p_delta double precision)
returns void
language plpgsql
security definer
as $$
begin
  perform set_config('search_path','pg_catalog, public', true);
  insert into public.metrics_counters(name, labels, value, updated_at)
  values (p_name, coalesce(p_labels,'{}'::jsonb), p_delta, now())
  on conflict(name, labels) do update set value = public.metrics_counters.value + excluded.value, updated_at = now();
end
$$;
revoke all on function public.metrics_add(text,jsonb,double precision) from public;
grant execute on function public.metrics_add(text,jsonb,double precision) to service_role;

-- Analyze for good stats post-migration
analyze public.risk_corridors_secure;
analyze public.v_risk_corridors_export;
