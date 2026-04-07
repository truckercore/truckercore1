-- Phase 1: Foundation and Tenancy for TruckerCore (Supabase/Postgres)
-- Run this in your Supabase SQL editor before feature-specific schemas.
-- Focus: organizations/tenants, users, roles, core fleet entities with audit columns, soft-delete, and RLS/permissions.

-- 0) Prerequisites
create extension if not exists pgcrypto; -- gen_random_uuid()

-- 1) Organizations (tenants)
create table if not exists public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index if not exists idx_orgs_not_deleted on public.organizations((deleted_at is null));

alter table public.organizations enable row level security;
-- Everyone authenticated can read own orgs by membership (policy below); separate open listing is typically not allowed.

-- 2) Roles and user memberships
-- App roles: fleet_manager, driver, broker, admin (optional)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'app_role') THEN
    CREATE TYPE public.app_role AS ENUM ('fleet_manager','driver','broker','admin');
  END IF;
END $$;

-- Link auth.users to organizations with roles. One user can belong to many orgs in different roles.
create table if not exists public.organization_members (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null, -- references auth.users(id) (cannot FK across schema in Supabase by default migrations; keep as loose reference)
  role public.app_role not null default 'fleet_manager',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (org_id, user_id)
);
create index if not exists idx_org_members_user on public.organization_members(user_id);

alter table public.organization_members enable row level security;

-- Policies assume JWT carries org_id and user_id claims. Adjust claim keys as needed.
-- Allow a user to see their memberships
drop policy if exists org_members_self on public.organization_members;
create policy org_members_self on public.organization_members
  for select using (auth.uid() = user_id);

-- 3) Convenience view: current session's org and role (based on JWT claim org_id)
create or replace view public.v_my_org_role as
select m.org_id, m.user_id, m.role, o.name, o.slug
from public.organization_members m
join public.organizations o on o.id = m.org_id
where m.user_id = auth.uid() and m.org_id = (auth.jwt() ->> 'org_id')::uuid;

-- 4) Common audit columns and soft-delete helpers
-- Add created_by, updated_by, created_at, updated_at, deleted_at to key tables.
-- We provide helper triggers to auto-fill timestamps.

create or replace function public.set_timestamp_updated_at() returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- 5) Core entities tied to org: drivers, trucks, terminals/yards, trips/loads
-- If you already created drivers/trucks in feature schema, you can ALTER those to add audit + soft-delete + RLS here.

-- Drivers (org-scoped)
create table if not exists public.drivers (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  full_name text not null,
  phone text,
  email text,
  status text default 'active',
  created_by uuid,
  updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index if not exists idx_drivers_org on public.drivers(org_id);
create index if not exists idx_drivers_not_deleted on public.drivers((deleted_at is null));

alter table public.drivers enable row level security;

-- Trucks (org-scoped)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'truck_status') THEN
    CREATE TYPE public.truck_status AS ENUM ('inactive','available','en_route','at_stop','maintenance','offline');
  END IF;
END $$;

create table if not exists public.trucks (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  external_id text,
  vin text,
  plate text,
  make text,
  model text,
  year int,
  status public.truck_status default 'available',
  current_driver_id uuid, -- nullable
  created_by uuid,
  updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index if not exists idx_trucks_org on public.trucks(org_id);
create index if not exists idx_trucks_status on public.trucks(status);
create index if not exists idx_trucks_not_deleted on public.trucks((deleted_at is null));

alter table public.trucks enable row level security;

-- Terminals/Yards (org-scoped)
create table if not exists public.terminals (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  lat double precision not null,
  lng double precision not null,
  address text,
  created_by uuid,
  updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index if not exists idx_terminals_org on public.terminals(org_id);

alter table public.terminals enable row level security;

-- Driver-Truck assignments (current and historical)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'assignment_status') THEN
    CREATE TYPE public.assignment_status AS ENUM ('planned','assigned','en_route','at_pickup','at_dropoff','completed','canceled');
  END IF;
END $$;

create table if not exists public.driver_truck_assignments (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  driver_id uuid not null references public.drivers(id) on delete cascade,
  truck_id uuid not null references public.trucks(id) on delete cascade,
  status public.assignment_status not null default 'assigned',
  assigned_at timestamptz not null default now(),
  unassigned_at timestamptz,
  created_by uuid,
  updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_dta_org on public.driver_truck_assignments(org_id);
create index if not exists idx_dta_driver on public.driver_truck_assignments(driver_id);
create index if not exists idx_dta_truck on public.driver_truck_assignments(truck_id);

alter table public.driver_truck_assignments enable row level security;

-- Trips/Loads (org-scoped)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'load_status') THEN
    CREATE TYPE public.load_status AS ENUM ('planned','en_route','delivered','canceled');
  END IF;
END $$;

create table if not exists public.loads (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  reference_number text,
  status public.load_status not null default 'planned',
  pickup_lat double precision,
  pickup_lng double precision,
  dropoff_lat double precision,
  dropoff_lng double precision,
  planned_pickup_at timestamptz,
  planned_dropoff_at timestamptz,
  actual_pickup_at timestamptz,
  actual_dropoff_at timestamptz,
  created_by uuid,
  updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index if not exists idx_loads_org on public.loads(org_id);
create index if not exists idx_loads_status on public.loads(status);

alter table public.loads enable row level security;

-- 6) RLS: enforce org scoping using JWT claim org_id and role-based permissions
-- Safety: if these tables already existed without org_id (from older installs), add the column now so policies do not fail.
alter table if exists public.drivers add column if not exists org_id uuid references public.organizations(id) on delete cascade;
alter table if exists public.trucks add column if not exists org_id uuid references public.organizations(id) on delete cascade;
alter table if exists public.terminals add column if not exists org_id uuid references public.organizations(id) on delete cascade;
alter table if exists public.driver_truck_assignments add column if not exists org_id uuid references public.organizations(id) on delete cascade;
alter table if exists public.loads add column if not exists org_id uuid references public.organizations(id) on delete cascade;
-- Helpful indexes in case columns were just added
create index if not exists idx_drivers_org on public.drivers(org_id);
create index if not exists idx_trucks_org on public.trucks(org_id);
create index if not exists idx_terminals_org on public.terminals(org_id);
create index if not exists idx_dta_org on public.driver_truck_assignments(org_id);
create index if not exists idx_loads_org on public.loads(org_id);
-- Helpers
create or replace function public.jwt_org_id() returns uuid language sql stable as $$
  select (auth.jwt() ->> 'org_id')::uuid
$$;

-- Organizations: read if member; write if admin/fleet_manager of that org.
drop policy if exists orgs_read_by_members on public.organizations;
create policy orgs_read_by_members on public.organizations
  for select using (exists (
    select 1 from public.organization_members m where m.org_id = organizations.id and m.user_id = auth.uid()
  ));

drop policy if exists orgs_write_by_admins on public.organizations;
create policy orgs_write_by_admins on public.organizations
  for update using (exists (
    select 1 from public.organization_members m where m.org_id = organizations.id and m.user_id = auth.uid() and m.role in ('admin','fleet_manager')
  ));

-- Organization members: self can read; admins can manage within org
drop policy if exists org_members_read_self on public.organization_members;
create policy org_members_read_self on public.organization_members
  for select using (auth.uid() = user_id or exists (
    select 1 from public.organization_members m where m.org_id = organization_members.org_id and m.user_id = auth.uid() and m.role in ('admin','fleet_manager')
  ));

drop policy if exists org_members_manage_admins on public.organization_members;
create policy org_members_manage_admins on public.organization_members
  for all using (exists (
    select 1 from public.organization_members m where m.org_id = organization_members.org_id and m.user_id = auth.uid() and m.role in ('admin','fleet_manager')
  )) with check (exists (
    select 1 from public.organization_members m where m.org_id = organization_members.org_id and m.user_id = auth.uid() and m.role in ('admin','fleet_manager')
  ));

-- Drivers: tenant scoping; drivers can read self if linked via auth.uid() in app logic (optional column)
drop policy if exists drivers_tenant_select on public.drivers;
create policy drivers_tenant_select on public.drivers
  for select using (org_id = public.jwt_org_id());
drop policy if exists drivers_tenant_cud_fleet on public.drivers;
create policy drivers_tenant_cud_fleet on public.drivers
  for all using (org_id = public.jwt_org_id() and exists (
    select 1 from public.organization_members m where m.org_id = public.jwt_org_id() and m.user_id = auth.uid() and m.role in ('admin','fleet_manager')
  )) with check (org_id = public.jwt_org_id());

-- Trucks
drop policy if exists trucks_tenant_select on public.trucks;
create policy trucks_tenant_select on public.trucks
  for select using (org_id = public.jwt_org_id());
drop policy if exists trucks_tenant_cud_fleet on public.trucks;
create policy trucks_tenant_cud_fleet on public.trucks
  for all using (org_id = public.jwt_org_id() and exists (
    select 1 from public.organization_members m where m.org_id = public.jwt_org_id() and m.user_id = auth.uid() and m.role in ('admin','fleet_manager')
  )) with check (org_id = public.jwt_org_id());

-- Terminals
drop policy if exists terminals_tenant_select on public.terminals;
create policy terminals_tenant_select on public.terminals
  for select using (org_id = public.jwt_org_id());
drop policy if exists terminals_tenant_cud_fleet on public.terminals;
create policy terminals_tenant_cud_fleet on public.terminals
  for all using (org_id = public.jwt_org_id() and exists (
    select 1 from public.organization_members m where m.org_id = public.jwt_org_id() and m.user_id = auth.uid() and m.role in ('admin','fleet_manager')
  )) with check (org_id = public.jwt_org_id());

-- Driver-Truck Assignments: drivers can read own assignments; fleet manage CRUD
drop policy if exists dta_tenant_select on public.driver_truck_assignments;
create policy dta_tenant_select on public.driver_truck_assignments
  for select using (org_id = public.jwt_org_id());
drop policy if exists dta_tenant_cud_fleet on public.driver_truck_assignments;
create policy dta_tenant_cud_fleet on public.driver_truck_assignments
  for all using (org_id = public.jwt_org_id() and exists (
    select 1 from public.organization_members m where m.org_id = public.jwt_org_id() and m.user_id = auth.uid() and m.role in ('admin','fleet_manager')
  )) with check (org_id = public.jwt_org_id());

-- Loads: broker can read subset, fleet_manager full; driver read assigned only via separate join/view later
drop policy if exists loads_tenant_select on public.loads;
create policy loads_tenant_select on public.loads
  for select using (org_id = public.jwt_org_id());
drop policy if exists loads_tenant_cud_fleet on public.loads;
create policy loads_tenant_cud_fleet on public.loads
  for all using (org_id = public.jwt_org_id() and exists (
    select 1 from public.organization_members m where m.org_id = public.jwt_org_id() and m.user_id = auth.uid() and m.role in ('admin','fleet_manager')
  )) with check (org_id = public.jwt_org_id());

-- 7) Soft delete helpers: set deleted_at instead of physical delete for selected tables
create or replace function public.soft_delete() returns trigger as $$
begin
  new.deleted_at = coalesce(new.deleted_at, now());
  return new;
end;
$$ language plpgsql;

-- Attach updated_at triggers
create trigger trg_orgs_updated_at before update on public.organizations for each row execute function public.set_timestamp_updated_at();
create trigger trg_drivers_updated_at before update on public.drivers for each row execute function public.set_timestamp_updated_at();
create trigger trg_trucks_updated_at before update on public.trucks for each row execute function public.set_timestamp_updated_at();
create trigger trg_terminals_updated_at before update on public.terminals for each row execute function public.set_timestamp_updated_at();
create trigger trg_loads_updated_at before update on public.loads for each row execute function public.set_timestamp_updated_at();

-- Note: To enforce soft-delete, replace deletes with updates setting deleted_at at application level or add INSTEAD OF triggers.

-- 8) Minimal seeds (optional) — create a demo org and a member admin, use Supabase dashboard to map users
-- Comment out if undesired.
-- Demo org
insert into public.organizations (name, slug)
select 'Demo Carrier', 'demo-carrier'
where not exists (select 1 from public.organizations where slug = 'demo-carrier');

-- To add a current user as admin to demo org, run this with your session:
-- insert into public.organization_members (org_id, user_id, role)
-- select id, auth.uid(), 'admin' from public.organizations where slug = 'demo-carrier'
-- on conflict (org_id, user_id) do nothing;
