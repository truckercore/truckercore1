-- 20250928_accounts_orgs.sql
-- Organizations
create table if not exists public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  tier text not null default 'Basic', -- Basic|Standard|Premium|Enterprise
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
alter table public.organizations enable row level security;

-- Profiles (users mirror auth.users)
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  locale text default 'en',
  app_is_premium boolean not null default false,
  created_at timestamptz not null default now()
);
alter table public.profiles enable row level security;
drop policy if exists "profile self read" on public.profiles;
create policy "profile self read" on public.profiles for select using (auth.uid() = id);
drop policy if exists "profile self update" on public.profiles;
create policy "profile self update" on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id);

-- Memberships
do $$ begin
  if not exists (select 1 from pg_type where typname='org_role') then
    create type public.org_role as enum ('owner_operator','fleet_manager','broker','truck_stop_admin');
  end if;
end $$;

create table if not exists public.org_memberships (
  user_id uuid references public.profiles(id) on delete cascade,
  org_id uuid references public.organizations(id) on delete cascade,
  role public.org_role not null,
  primary key (user_id, org_id)
);
alter table public.org_memberships enable row level security;
drop policy if exists "members read own orgs" on public.org_memberships;
create policy "members read own orgs" on public.org_memberships for select using (auth.uid() = user_id);
drop policy if exists "members upsert self" on public.org_memberships;
create policy "members upsert self" on public.org_memberships for insert with check (auth.uid() = user_id);

-- Credentials per org
create table if not exists public.org_credentials (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  dot text,
  mc text,
  scac text,
  ein_last4 text,
  ein_hash text,
  insurance_coi_url text,
  documents jsonb not null default '{}'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create index if not exists idx_org_credentials_org on public.org_credentials (org_id);

-- Verifications
do $$ begin
  if not exists (select 1 from pg_type where typname='verification_status') then
    create type public.verification_status as enum ('pending','verified','rejected');
  end if;
end $$;

create table if not exists public.verifications (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  source text not null,
  status public.verification_status not null default 'pending',
  notes text,
  checks jsonb not null default '{}'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create index if not exists idx_verifications_org on public.verifications (org_id);

-- Subscriptions (Stripe mirror)
create table if not exists public.subscriptions (
  id uuid primary key,
  org_id uuid not null references public.organizations(id) on delete cascade,
  stripe_customer_id text not null,
  stripe_price_id text not null,
  tier text not null,
  status text not null,
  seats int default 1,
  current_period_end timestamptz,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create index if not exists idx_subscriptions_org on public.subscriptions (org_id);

-- Device installs/licensing
create table if not exists public.device_installs (
  install_id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  role public.org_role not null,
  tier text not null,
  device_fingerprint text not null,
  issued_at timestamptz not null default now(),
  revoked_at timestamptz
);
create index if not exists idx_device_installs_org_role on public.device_installs (org_id, role);

-- Utility: hash EIN using pgcrypto
create extension if not exists pgcrypto;
create or replace function public.hash_ein(p_ein text)
returns text language sql immutable as $$ select encode(digest(coalesce(p_ein,''), 'sha256'), 'hex') $$;

-- Trigger to keep updated_at fresh
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$ begin new.updated_at = now(); return new; end $$;

drop trigger if exists trg_touch_org_credentials on public.org_credentials;
create trigger trg_touch_org_credentials before update on public.org_credentials for each row execute procedure public.touch_updated_at();

drop trigger if exists trg_touch_verifications on public.verifications;
create trigger trg_touch_verifications before update on public.verifications for each row execute procedure public.touch_updated_at();
