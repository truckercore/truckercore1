-- 20250923_ops_preflight_log.sql
-- Purpose: Ops preflight audit table with RLS for read (authenticated) and service-role insert.
-- Safe to re-run.

create table if not exists public.ops_preflight_log (
  id bigserial primary key,
  ran_at timestamptz not null default now(),
  ok boolean not null,
  details jsonb
);

alter table public.ops_preflight_log enable row level security;

-- Read allowed for authenticated (no sensitive secrets in details; keep terse)
create policy if not exists ops_preflight_read on public.ops_preflight_log
for select to authenticated using (true);

-- Ensure no public/anon rights beyond RLS
revoke all on public.ops_preflight_log from public;
revoke all on public.ops_preflight_log from anon;
revoke all on public.ops_preflight_log from authenticated;
grant select on public.ops_preflight_log to authenticated;
