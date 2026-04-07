-- 1) Core tables
create table if not exists public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.org_memberships (
  org_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null,
  role text not null check (role in ('owner-operator','fleet-manager','freight-broker','truck-stop','admin','manager','analyst','viewer')),
  created_at timestamptz not null default now(),
  primary key (org_id, user_id)
);

create table if not exists public.safety_summaries (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  summary_date date not null,
  metrics jsonb not null,
  created_by uuid not null,
  created_at timestamptz not null default now()
);

create table if not exists public.alerts (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  corridor_id text not null,
  severity text not null check (severity in ('low','medium','high','critical')),
  message text not null,
  happened_at timestamptz not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- 2) View for CSV export
create or replace view public.alerts_export_view as
select
  a.id,
  a.org_id,
  a.corridor_id,
  a.severity,
  a.message,
  a.happened_at,
  (a.metadata->>'source') as source,
  (a.metadata->>'device') as device
from public.alerts a;

-- 3) RLS enablement
alter table public.organizations enable row level security;
alter table public.org_memberships enable row level security;
alter table public.safety_summaries enable row level security;
alter table public.alerts enable row level security;

-- Helpers to read claims
create or replace function public.jwt_org_id() returns text
language sql stable as $$
  select coalesce(current_setting('request.jwt.claims', true)::jsonb->>'app_org_id','');
$$;

create or replace function public.jwt_role() returns text
language sql stable as $$
  select coalesce(current_setting('request.jwt.claims', true)::jsonb->>'app_role','');
$$;

-- Basic read policies (org-scoped)
create policy org_read_orgs on public.organizations
  for select using (id::text = public.jwt_org_id());

create policy org_read_memberships on public.org_memberships
  for select using (org_id::text = public.jwt_org_id());

create policy org_read_safety on public.safety_summaries
  for select using (org_id::text = public.jwt_org_id());

create policy org_read_alerts on public.alerts
  for select using (org_id::text = public.jwt_org_id());

-- 4) Export role gate at DB
create or replace function public.has_export_privilege()
returns boolean
language sql stable as $$
  select public.jwt_role() in ('admin','manager','fleet-manager','truck-stop');
$$;

-- Tighten alerts read for exporters (keeps base policy for general readers)
drop policy if exists org_read_alerts_export on public.alerts;
create policy org_read_alerts_export on public.alerts
  for select using (
    org_id::text = public.jwt_org_id()
    and public.has_export_privilege()
  );

-- 5) Corridor risk daily (org-scoped)
create table if not exists public.corridor_risk_daily (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  corridor_id text not null,
  day date not null,
  incidents int not null default 0,
  high_or_worse int not null default 0,
  created_at timestamptz not null default now()
);

alter table public.corridor_risk_daily enable row level security;

create policy org_read_corridor_risk on public.corridor_risk_daily
  for select using (org_id::text = public.jwt_org_id());
