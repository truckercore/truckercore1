-- 03_activity_audit.sql
-- Activity audit log to capture compact user-visible actions

create table if not exists public.activity_log (
  id uuid primary key default gen_random_uuid(),
  org_id uuid,
  user_id uuid,
  action text not null,           -- e.g., 'search','request','counter','watch_toggle'
  details jsonb default '{}'::jsonb,
  occurred_at timestamptz default now()
);
create index if not exists idx_activity_log_org on public.activity_log(org_id);
create index if not exists idx_activity_log_user on public.activity_log(user_id);
create index if not exists idx_activity_log_action_time on public.activity_log(action, occurred_at desc);
