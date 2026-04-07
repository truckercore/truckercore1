-- docs/supabase/fleet_core_schema.sql
-- Minimal schema for Fleet Drivers, Members, and Invites per spec.
-- Safe to re-run due to IF NOT EXISTS and DO blocks.

create extension if not exists pgcrypto;

-- Enums
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'driver_status') THEN
    CREATE TYPE public.driver_status AS ENUM ('active','suspended','pending');
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'fleet_role') THEN
    CREATE TYPE public.fleet_role AS ENUM ('driver','dispatcher','safety','admin');
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'invite_status') THEN
    CREATE TYPE public.invite_status AS ENUM ('pending','accepted','revoked');
  END IF;
END $$;

-- Tables
create table if not exists public.drivers (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  user_id uuid references auth.users(id) on delete set null,
  license_no text,
  truck_id uuid,
  status public.driver_status not null default 'pending',
  created_at timestamptz not null default now()
);
create index if not exists idx_drivers_org on public.drivers(org_id);
create index if not exists idx_drivers_user on public.drivers(user_id);

create table if not exists public.fleet_members (
  org_id uuid not null,
  user_id uuid not null,
  role public.fleet_role not null,
  created_at timestamptz not null default now(),
  primary key(org_id, user_id)
);
create index if not exists idx_fleet_members_role on public.fleet_members(role);

create table if not exists public.driver_invites (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  email text,
  phone text,
  role public.fleet_role not null,
  token text unique not null,
  status public.invite_status not null default 'pending',
  created_at timestamptz not null default now()
);
create unique index if not exists uq_driver_invites_token on public.driver_invites(token);
create index if not exists idx_driver_invites_org on public.driver_invites(org_id);

-- RLS
alter table public.drivers enable row level security;
alter table public.fleet_members enable row level security;
alter table public.driver_invites enable row level security;

-- Helper: checks if JWT has manager role (dispatcher/safety/admin) for org
create or replace function public.has_manager_role(p_org uuid)
returns boolean language sql stable as $$
  select coalesce(
    (auth.jwt() ->> 'app_org_id')::uuid = p_org
    and (auth.jwt() ->> 'app_role') IN ('admin','dispatcher','safety'), false);
$$;

-- drivers policies: drivers can see self by user_id; managers by org
drop policy if exists drivers_self_or_org_select on public.drivers;
create policy drivers_self_or_org_select on public.drivers for select using (
  user_id = auth.uid() or has_manager_role(org_id)
);

drop policy if exists drivers_self_update on public.drivers;
create policy drivers_self_update on public.drivers for update using (
  user_id = auth.uid() or has_manager_role(org_id)
);

drop policy if exists drivers_org_insert on public.drivers;
create policy drivers_org_insert on public.drivers for insert with check (
  has_manager_role(org_id)
);

-- fleet_members: org-scoped reads
drop policy if exists fleet_members_org_select on public.fleet_members;
create policy fleet_members_org_select on public.fleet_members for select using (
  (auth.jwt() ->> 'app_org_id')::uuid = org_id
);

-- driver_invites: org-scoped insert/select; accept via RPC without RLS
drop policy if exists driver_invites_org_select on public.driver_invites;
create policy driver_invites_org_select on public.driver_invites for select using (
  has_manager_role(org_id)
);

drop policy if exists driver_invites_org_insert on public.driver_invites;
create policy driver_invites_org_insert on public.driver_invites for insert with check (
  has_manager_role(org_id)
);

-- RPC: accept driver invite (token-only pathway)
-- Assumes caller is an authenticated user (mobile app) possessing token from invite link
-- Links user to org with role if not present; marks invite accepted; creates driver row if role=driver
create or replace function public.accept_driver_invite(p_token text)
returns table(user_id uuid, org_id uuid, role public.fleet_role) 
language plpgsql security definer as $$
DECLARE
  v_inv driver_invites%rowtype;
  v_uid uuid := auth.uid();
  v_driver_id uuid;
BEGIN
  if p_token is null or length(p_token) < 10 then
    raise exception 'invalid_token';
  end if;
  select * into v_inv from driver_invites where token = p_token and status = 'pending';
  if not found then
    raise exception 'invite_not_found_or_used';
  end if;

  if v_uid is null then
    raise exception 'auth_required';
  end if;

  -- Upsert fleet_members
  insert into fleet_members(org_id, user_id, role)
  values (v_inv.org_id, v_uid, v_inv.role)
  on conflict (org_id, user_id) do update set role = excluded.role;

  -- Create driver row if role is driver and no driver row exists
  if v_inv.role = 'driver' then
    insert into drivers(org_id, user_id, status)
    values (v_inv.org_id, v_uid, 'active')
    on conflict do nothing
    returning id into v_driver_id;
  end if;

  update driver_invites set status = 'accepted' where id = v_inv.id;

  return query select v_uid as user_id, v_inv.org_id as org_id, v_inv.role as role;
END $$;

-- Note: You may add throttling on invites via a trigger or a separate invites_outbox table.
