-- Shipper Portal 2.0 minimal schema extensions

-- 1) market_rates: add forecast_rate_cents (nullable)
alter table if exists public.market_rates
  add column if not exists forecast_rate_cents int null,
  add column if not exists model_updated_at timestamptz null;

-- 2) inspection_reports: add maintenance resolution fields
alter table if exists public.inspection_reports
  add column if not exists resolved_at timestamptz null,
  add column if not exists repair_notes text null;

-- 3) maintenance_jobs table
create table if not exists public.maintenance_jobs (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  vehicle_id uuid not null,
  inspection_id uuid null references public.inspection_reports(id) on delete set null,
  defect jsonb not null,
  opened_at timestamptz not null default now(),
  closed_at timestamptz null,
  notes text null,
  created_at timestamptz not null default now()
);
create index if not exists idx_maint_jobs_vehicle_open on public.maintenance_jobs (vehicle_id, opened_at desc);
alter table public.maintenance_jobs enable row level security;
create policy maintenance_jobs_read on public.maintenance_jobs for select to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
create policy maintenance_jobs_write on public.maintenance_jobs for insert to authenticated
with check (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
create policy maintenance_jobs_update on public.maintenance_jobs for update to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''))
with check (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

-- 4) combo_loads for bundling loads into one offer
create table if not exists public.combo_loads (
  id uuid primary key default gen_random_uuid(),
  broker_id uuid not null,
  load_ids uuid[] not null,
  created_at timestamptz not null default now()
);
create index if not exists idx_combo_broker on public.combo_loads (broker_id, created_at desc);
alter table public.combo_loads enable row level security;
create policy combo_rw on public.combo_loads for all to authenticated
using (broker_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'sub',''))
with check (broker_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'sub',''));

-- 5) fleet_brand_settings (one row per org)
create table if not exists public.fleet_brand_settings (
  org_id uuid primary key,
  logo_url text null,
  primary_color text null,
  secondary_color text null,
  accent_color text null,
  updated_at timestamptz not null default now()
);
alter table public.fleet_brand_settings enable row level security;
create policy fleet_brand_rw on public.fleet_brand_settings for all to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''))
with check (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

-- 6) billing_audit (fallback when STRIPE not configured)
create table if not exists public.billing_audit (
  id uuid primary key default gen_random_uuid(),
  broker_id uuid not null,
  amount_cents int not null,
  note text null,
  created_at timestamptz not null default now()
);
create index if not exists idx_billing_audit_broker_time on public.billing_audit (broker_id, created_at desc);
alter table public.billing_audit enable row level security;
create policy billing_audit_read on public.billing_audit for select to authenticated
using (true);
