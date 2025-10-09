-- 20250923_ops_maintenance.sql
-- Purpose: Ops maintenance log table + exec_sql RPC for server-side ad-hoc SQL.
-- Safe to re-run.

-- 1) Maintenance log table -----------------------------------------------------
create table if not exists public.ops_maintenance_log (
  id bigserial primary key,
  ran_at timestamptz not null default now(),
  task text not null,          -- e.g., 'nightly_maintenance'
  ok boolean not null,
  ms integer not null,
  details jsonb
);

create index if not exists ops_maint_log_ran_at_idx on public.ops_maintenance_log (ran_at desc);

-- 2) Minimal RPC helper for ad-hoc SQL (server-only) ---------------------------
create or replace function public.exec_sql(sql text)
returns void
language plpgsql
security definer
as $$
begin
  execute sql;
end $$;

-- Lock down exec_sql to server-side only
revoke all on function public.exec_sql(text) from public;
revoke all on function public.exec_sql(text) from anon;
revoke all on function public.exec_sql(text) from authenticated;
grant execute on function public.exec_sql(text) to service_role;
