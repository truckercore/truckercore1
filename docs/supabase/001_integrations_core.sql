-- 001_integrations_core.sql
create extension if not exists pgcrypto;
create extension if not exists postgis;

-- Tenancy Orgs
create table if not exists public.orgs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz default now()
);

-- Idempotency keys (per provider, org-scoped)
create table if not exists public.idempotency_keys (
  key text primary key,
  seen_at timestamptz default now(),
  provider text not null,
  org_id uuid references public.orgs(id) on delete cascade
);

-- Integrations/Connections
create table if not exists public.integrations (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id) on delete cascade,
  provider text not null,
  access_token text,
  refresh_token text,
  expires_at timestamptz,
  scope text,
  external_account_id text,
  connection_status text default 'active',
  last_sync_at timestamptz,
  created_at timestamptz default now(),
  unique (org_id, provider)
);

-- Canonical Fleet Entities
create table if not exists public.drivers (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id) on delete cascade,
  external_id text,
  name text,
  license_number text,
  phone text,
  email text,
  provider text,
  unique (org_id, provider, external_id)
);

create table if not exists public.vehicles (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id) on delete cascade,
  external_id text,
  vin text,
  plate text,
  make text,
  model text,
  year int,
  provider text,
  unique (org_id, provider, external_id)
);

create table if not exists public.trailers (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id) on delete cascade,
  external_id text,
  number text,
  type text,
  provider text,
  unique (org_id, provider, external_id)
);

-- Telemetry/Positions
create table if not exists public.positions (
  id bigserial primary key,
  org_id uuid not null references public.orgs(id) on delete cascade,
  vehicle_id uuid references public.vehicles(id) on delete set null,
  driver_id uuid references public.drivers(id) on delete set null,
  provider text not null,
  provider_msg_id text,
  ts timestamptz not null,
  geom geometry(Point, 4326) not null,
  speed_kph numeric,
  heading numeric,
  hdop numeric,
  ignition bool,
  unique (provider, provider_msg_id)
);
create index if not exists idx_positions_org_ts on public.positions (org_id, ts desc);
create index if not exists idx_positions_geom on public.positions using gist (geom);

-- HOS
create table if not exists public.hos_logs_ext (
  id bigserial primary key,
  org_id uuid not null references public.orgs(id) on delete cascade,
  driver_id uuid references public.drivers(id) on delete set null,
  status text not null check (status in ('off','sb','dr','on')),
  started_at timestamptz not null,
  ended_at timestamptz,
  provider text not null,
  provider_log_id text not null,
  unique (provider, provider_log_id)
);
create index if not exists idx_hos_ext_org_time on public.hos_logs_ext (org_id, started_at desc);

-- DVIR defects -> maintenance work order handoff
create table if not exists public.dvir_defects_ext (
  id bigserial primary key,
  org_id uuid not null references public.orgs(id) on delete cascade,
  vehicle_id uuid references public.vehicles(id),
  driver_id uuid references public.drivers(id),
  noted_at timestamptz not null,
  component text,
  severity text,
  notes text,
  provider text,
  provider_defect_id text,
  status text default 'open',
  unique (provider, provider_defect_id)
);
create index if not exists idx_dvir_ext_org_time on public.dvir_defects_ext (org_id, noted_at desc);

-- Fuel for IFTA
create table if not exists public.fuel_transactions_ext (
  id bigserial primary key,
  org_id uuid not null references public.orgs(id) on delete cascade,
  vehicle_id uuid references public.vehicles(id),
  ts timestamptz not null,
  merchant text,
  amount_usd numeric,
  gallons numeric,
  fuel_type text,
  state_province text,
  source text,
  external_id text,
  unique (source, external_id)
);
create index if not exists idx_fuel_ext_org_time on public.fuel_transactions_ext (org_id, ts desc);

-- TMS Loads/Dispatch
create table if not exists public.loads_ext (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id) on delete cascade,
  tms_id text,
  status text default 'planned',
  pickup_at timestamptz,
  delivery_at timestamptz,
  origin jsonb,
  destination jsonb,
  equipment text,
  notes text,
  unique (org_id, tms_id)
);
create index if not exists idx_loads_ext_org_time on public.loads_ext (org_id, pickup_at desc);

create table if not exists public.dispatches_ext (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id) on delete cascade,
  load_id uuid not null references public.loads_ext(id) on delete cascade,
  driver_id uuid references public.drivers(id),
  vehicle_id uuid references public.vehicles(id),
  status text default 'assigned',
  eta_delivery timestamptz,
  created_at timestamptz default now()
);

-- Accounting (QuickBooks)
create table if not exists public.invoices_ext (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id) on delete cascade,
  load_id uuid references public.loads_ext(id) on delete set null,
  qbo_txn_id text,
  status text default 'draft',
  amount_usd numeric,
  issued_at timestamptz,
  due_at timestamptz
);
create index if not exists idx_invoices_ext_org_time on public.invoices_ext (org_id, issued_at desc);

-- RLS Policies
alter table public.orgs enable row level security;
alter table public.idempotency_keys enable row level security;
alter table public.integrations enable row level security;
alter table public.drivers enable row level security;
alter table public.vehicles enable row level security;
alter table public.trailers enable row level security;
alter table public.positions enable row level security;
alter table public.hos_logs_ext enable row level security;
alter table public.dvir_defects_ext enable row level security;
alter table public.fuel_transactions_ext enable row level security;
alter table public.loads_ext enable row level security;
alter table public.dispatches_ext enable row level security;
alter table public.invoices_ext enable row level security;

create or replace function public._jwt_org() returns uuid language sql stable as
$$ select nullif(current_setting('request.jwt.claims', true)::jsonb->>'app_org_id','')::uuid $$;

-- Apply read/write policies
DO $$
DECLARE t text;
BEGIN
  FOR t IN
    SELECT tablename FROM pg_tables WHERE schemaname='public' AND tablename IN
      ('idempotency_keys','integrations','drivers','vehicles','trailers','positions','hos_logs_ext','dvir_defects_ext','fuel_transactions_ext','loads_ext','dispatches_ext','invoices_ext')
  LOOP
    EXECUTE format('drop policy if exists %I_rw on public.%I', t||'_rw', t);
    EXECUTE format('create policy %I_rw on public.%I for all to authenticated using (org_id = public._jwt_org()) with check (org_id = public._jwt_org())', t||'_rw', t);
  END LOOP;

  -- orgs: read-only within org
  PERFORM 1;
  DROP POLICY IF EXISTS orgs_ro ON public.orgs;
  CREATE POLICY orgs_ro ON public.orgs FOR SELECT TO authenticated
  USING (id = public._jwt_org());
END $$;

-- Idempotency helper
create or replace function public.mark_idempotent(p_key text, p_provider text, p_org uuid)
returns boolean
language plpgsql
security definer
as $$
begin
  insert into public.idempotency_keys(key, provider, org_id)
  values (p_key, p_provider, p_org)
  on conflict (key) do nothing;
  return found;
end $$;

revoke all on function public.mark_idempotent(text,text,uuid) from public;
grant execute on function public.mark_idempotent(text,text,uuid) to service_role;
