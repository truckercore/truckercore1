-- Phase 5 — AI Assistant indexes, audit log, and policies

-- Speed up AI assistant context queries
create index if not exists idx_hos_driver_org on public.hos_logs (org_id, driver_user_id);
create index if not exists idx_inspection_org on public.inspection_reports (org_id, driver_user_id);
create index if not exists idx_expenses_user on public.ownerop_expenses (user_id, incurred_on desc);

-- AI audit log: records every assistant interaction
create table if not exists public.ai_audit_log (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  user_id uuid not null,
  role text not null check (role in ('driver','ownerop','fleet_manager','broker','shipper','admin')),
  plan_tier text not null check (plan_tier in ('free','pro','premium','enterprise')),
  provider text not null,
  model text not null,
  prompt text not null,
  answer_excerpt text,
  tokens_prompt int check (tokens_prompt >= 0),
  tokens_completion int check (tokens_completion >= 0),
  latency_ms int check (latency_ms >= 0),
  status text not null check (status in ('ok','error')),
  error text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_ai_audit_org_time on public.ai_audit_log (org_id, created_at desc);
create index if not exists idx_ai_audit_user_time on public.ai_audit_log (user_id, created_at desc);

alter table public.ai_audit_log enable row level security;

-- Org-scoped read
drop policy if exists ai_audit_read_org on public.ai_audit_log;
create policy ai_audit_read_org
on public.ai_audit_log
for select
to authenticated
using ( org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','') );

-- Service role write (Edge function)
drop policy if exists ai_audit_write_service on public.ai_audit_log;
create policy ai_audit_write_service
on public.ai_audit_log
for insert
to service_role
with check (true);
