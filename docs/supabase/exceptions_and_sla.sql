-- docs/supabase/exceptions_and_sla.sql
-- Exceptions queue, SLA policies, indexes, and RLS. Idempotent and safe to re-run.

create extension if not exists pgcrypto;

-- Exceptions queue
create table if not exists public.exceptions_queue (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  kind text not null check (kind in ('uncontacted','expiring_window','missing_docs','declined_offers','billing_flag','detention_risk')),
  entity_type text not null check (entity_type in ('load','stop','invoice','carrier')),
  entity_id uuid not null,
  severity text not null check (severity in ('p0','p1','p2','p3')),
  status text not null default 'open' check (status in ('open','ack','snoozed','resolved')),
  sla_due_at timestamptz not null,
  assigned_role text null check (assigned_role in ('corp_admin','regional_manager','fleet_manager','dispatcher','broker','billing')),
  assigned_user_id uuid null,
  payload jsonb not null default '{}'::jsonb,
  acked_at timestamptz null,
  resolved_at timestamptz null,
  snoozed_until timestamptz null,
  created_at timestamptz not null default now()
);
create index if not exists idx_exc_org_status on public.exceptions_queue (org_id, status);
create index if not exists idx_exc_sla_due on public.exceptions_queue (sla_due_at);

-- SLA templates per kind/role
create table if not exists public.sla_policies (
  org_id uuid not null,
  kind text not null,
  role text not null,
  ack_minutes int not null,
  resolve_minutes int not null,
  primary key (org_id, kind, role)
);

-- RLS
alter table public.exceptions_queue enable row level security;
alter table public.sla_policies enable row level security;

create or replace function public.jwt_claim(claim text)
returns text stable language sql as $$ select coalesce(current_setting('request.jwt.claims', true)::json->>claim, '') $$;

create policy if not exists exc_read_org on public.exceptions_queue
for select to authenticated
using (org_id::text = public.jwt_claim('app_org_id'));

create policy if not exists exc_update_roles on public.exceptions_queue
for update to authenticated
using (org_id::text = public.jwt_claim('app_org_id'))
with check (true);

create policy if not exists sla_read_org on public.sla_policies
for select to authenticated
using (org_id::text = public.jwt_claim('app_org_id'));

-- Helper view to compute SLA due based on policy (optional)
create or replace view public.v_exceptions_with_sla as
select e.*,
       sp.ack_minutes,
       sp.resolve_minutes
from public.exceptions_queue e
left join public.sla_policies sp on sp.org_id = e.org_id and sp.kind = e.kind and (sp.role = e.assigned_role or sp.role = 'dispatcher');
