-- Organizations and profiles
create table if not exists public.orgs (
  id uuid primary key,
  name text not null,
  plan text not null default 'free' check (plan in ('free','pro','enterprise')),
  created_at timestamptz not null default now()
);

create table if not exists public.profiles (
  user_id uuid primary key,
  org_id uuid not null references public.orgs(id),
  role text not null default 'driver' check (role in ('owner_op','driver','dispatcher','fleet_manager','admin')),
  app_is_premium boolean not null default false,
  created_at timestamptz not null default now()
);

-- Common RLS helpers
create or replace view public.v_current_app_org as
select coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','')::uuid as org_id;

alter table public.orgs enable row level security;
alter table public.profiles enable row level security;

create policy orgs_read_self on public.orgs
for select to authenticated
using (id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

create policy profiles_rw_self on public.profiles
for all to authenticated
using (user_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'sub',''))
with check (user_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'sub',''));

-- Vehicles (used in seed and IFTA)
create table if not exists public.vehicles (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id),
  vin text not null,
  plate text,
  make text,
  model text,
  year int,
  odo_miles int,
  created_at timestamptz not null default now()
);
create index if not exists idx_vehicles_org on public.vehicles(org_id);
alter table public.vehicles enable row level security;
create policy vehicles_org_rw on public.vehicles
for all to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''))
with check (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
