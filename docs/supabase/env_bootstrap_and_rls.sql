-- Env bootstrap and RLS wiring for health, profiles org claim, and escalation logs

-- Public health ping view
create or replace view public.health_ping_view as
select now() as now;

grant select on public.health_ping_view to anon, authenticated;

-- profiles org id (if not present)
alter table if exists public.profiles
  add column if not exists app_org_id uuid;

-- Escalation logs with org-scoped RLS by custom JWT claim `app_org_id`
create table if not exists public.escalation_logs (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  owner_id uuid,
  title text not null,
  status text not null default 'open',
  created_at timestamptz not null default now()
);

alter table public.escalation_logs enable row level security;

drop policy if exists "org read" on public.escalation_logs;
create policy "org read" on public.escalation_logs
for select using (
  org_id::text = current_setting('request.jwt.claims', true)::jsonb->>'app_org_id'
);

drop policy if exists "org write" on public.escalation_logs;
create policy "org write" on public.escalation_logs
for insert with check (
  org_id::text = current_setting('request.jwt.claims', true)::jsonb->>'app_org_id'
);

-- Edge function RPC for health
create or replace function public.edge_health_now()
returns timestamptz language sql stable
as $$ select now() $$;
