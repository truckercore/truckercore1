-- docs/supabase/finance_pricing.sql
-- Dynamic pricing rules, load margins, and accruals. Idempotent and safe to re-run.

create extension if not exists pgcrypto;

-- Dynamic pricing rules
create table if not exists public.pricing_rules (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  scope text not null check (scope in ('lane','customer','carrier','global')),
  key text not null,
  rule jsonb not null,
  active boolean not null default true,
  starts_at timestamptz not null default now(),
  ends_at timestamptz null,
  created_at timestamptz not null default now()
);
create index if not exists idx_pricing_org_key on public.pricing_rules (org_id, key);

-- Margin snapshots per load
create table if not exists public.load_margins (
  load_id uuid primary key,
  org_id uuid not null,
  revenue_cents int not null,
  buy_cost_cents int not null,
  accessorials_cents int not null default 0,
  fuel_surcharge_cents int not null default 0,
  margin_cents int not null,
  margin_pct numeric(6,3) not null,
  computed_at timestamptz not null default now()
);
create index if not exists idx_margins_org_time on public.load_margins (org_id, computed_at desc);

-- Accruals (fleets/brokers)
create table if not exists public.accruals (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  entity_type text not null check (entity_type in ('load','driver','carrier','customer')),
  entity_id uuid not null,
  period date not null,
  revenue_cents int not null default 0,
  cost_cents int not null default 0,
  accrual_cents int not null default 0,
  notes text null,
  created_at timestamptz not null default now(),
  unique (org_id, entity_type, entity_id, period)
);
create index if not exists idx_accruals_org_period on public.accruals (org_id, period);

-- RLS helpers
alter table public.pricing_rules enable row level security;
alter table public.load_margins enable row level security;
alter table public.accruals enable row level security;

create or replace function public.jwt_claim(claim text)
returns text stable language sql as $$ select coalesce(current_setting('request.jwt.claims', true)::json->>claim, '') $$;

create policy if not exists pricing_read_org on public.pricing_rules for select to authenticated using (org_id::text = public.jwt_claim('app_org_id'));
create policy if not exists pricing_write_admin on public.pricing_rules for all to authenticated using (org_id::text = public.jwt_claim('app_org_id')) with check (org_id::text = public.jwt_claim('app_org_id'));

create policy if not exists margins_read_org on public.load_margins for select to authenticated using (org_id::text = public.jwt_claim('app_org_id'));

create policy if not exists accruals_rw_org on public.accruals for all to authenticated using (org_id::text = public.jwt_claim('app_org_id')) with check (org_id::text = public.jwt_claim('app_org_id'));
