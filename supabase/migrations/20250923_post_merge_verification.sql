-- 20250923_post_merge_verification.sql
-- Purpose: Align DB to post-merge checklist: health ping view and org-scoped RLS for escalation_logs.
-- Safe to re-run.

-- Health ping view (anon readable)
create or replace view public.health_ping_view as
select now() as now;

revoke all on public.health_ping_view from public;
grant select on public.health_ping_view to anon, authenticated;

-- Ensure escalation_logs table exists; add org_id if missing (nullable first to allow backfill)
create table if not exists public.alerts (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  severity text check (severity in ('low','medium','high','critical')) default 'low',
  status text check (status in ('open','ack','resolved')) default 'open',
  created_at timestamptz not null default now()
);

create table if not exists public.escalation_logs (
  id uuid primary key default gen_random_uuid(),
  alert_id uuid not null references public.alerts(id) on delete cascade,
  title text not null,
  status text check (status in ('open','investigating','mitigated','closed')) default 'open',
  owner_id uuid,
  owner_name text,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.escalation_logs
  add column if not exists org_id uuid;

create index if not exists escalation_logs_created_at_idx on public.escalation_logs (created_at desc);
create index if not exists escalation_logs_alert_idx on public.escalation_logs (alert_id);
create index if not exists escalation_logs_org_idx on public.escalation_logs (org_id);

-- Enable RLS
alter table public.escalation_logs enable row level security;

-- Policies: require org match from JWT custom claim app_org_id
-- Helper expression to read claim
-- Note: Supabase exposes JWT via current_setting('request.jwt.claims', true)

-- SELECT policy
create policy if not exists "org read"
  on public.escalation_logs
  for select
  using (
    coalesce(org_id::text, '') = coalesce(current_setting('request.jwt.claims', true)::jsonb->>'app_org_id', '')
  );

-- INSERT policy: only allow when new.org_id matches claim
create policy if not exists "org insert"
  on public.escalation_logs
  for insert
  with check (
    coalesce(org_id::text, '') = coalesce(current_setting('request.jwt.claims', true)::jsonb->>'app_org_id', '')
  );

-- UPDATE policy (optional): only within org
create policy if not exists "org update"
  on public.escalation_logs
  for update
  using (
    coalesce(org_id::text, '') = coalesce(current_setting('request.jwt.claims', true)::jsonb->>'app_org_id', '')
  )
  with check (
    coalesce(org_id::text, '') = coalesce(current_setting('request.jwt.claims', true)::jsonb->>'app_org_id', '')
  );
