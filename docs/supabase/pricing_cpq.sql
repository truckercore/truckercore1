-- docs/supabase/pricing_cpq.sql
-- Discount approvals, quotes, and RLS for CPQ. Idempotent and safe to re-run.

create extension if not exists pgcrypto;

-- Discount matrix approvals
create table if not exists public.discount_approvals (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  requested_by uuid not null,
  tier text not null check (tier in ('per_location','multi_location','enterprise')),
  list_price_cents int not null,
  proposed_discount_pct numeric(5,2) not null check (proposed_discount_pct between 0 and 90),
  rationale text not null,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  approved_by uuid null,
  approved_at timestamptz null,
  created_at timestamptz not null default now()
);
create index if not exists idx_discount_approvals_org on public.discount_approvals (org_id, created_at desc);
alter table public.discount_approvals enable row level security;

create or replace function public.jwt_claim(claim text)
returns text stable language sql as $$ select coalesce(current_setting('request.jwt.claims', true)::json->>claim, '') $$;

create policy discount_approvals_read_org on public.discount_approvals for select to authenticated
using (org_id::text = public.jwt_claim('app_org_id'));
create policy discount_approvals_write_mgr on public.discount_approvals for insert to authenticated
with check (org_id::text = public.jwt_claim('app_org_id'));
create policy discount_approvals_update_admin on public.discount_approvals for update to authenticated
using ((coalesce(current_setting('request.jwt.claims', true)::json->'app_roles','[]'::json) ? 'corp_admin'))
with check (true);

-- Quote templates and quotes
create table if not exists public.quote_templates (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  currency text not null default 'USD',
  payload jsonb not null,
  created_at timestamptz not null default now()
);

create table if not exists public.quotes (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  template_id uuid not null references public.quote_templates(id),
  seats int null,
  locations int null,
  term_months int not null default 12,
  list_total_cents int not null,
  discount_pct numeric(5,2) not null default 0,
  final_total_cents int not null,
  status text not null default 'draft' check (status in ('draft','sent','accepted','expired')),
  notes text null,
  created_by uuid not null,
  created_at timestamptz not null default now(),
  sent_at timestamptz null,
  accepted_at timestamptz null
);
create index if not exists idx_quotes_org on public.quotes (org_id, created_at desc);
alter table public.quotes enable row level security;
create policy quotes_read_org on public.quotes for select to authenticated
using (org_id::text = public.jwt_claim('app_org_id'));
create policy quotes_write_mgr on public.quotes for insert to authenticated
with check (org_id::text = public.jwt_claim('app_org_id'));
create policy quotes_update_mgr on public.quotes for update to authenticated
using (org_id::text = public.jwt_claim('app_org_id'))
with check (org_id::text = public.jwt_claim('app_org_id'));

-- Optional: approval linkage
alter table public.quotes add column if not exists approval_id uuid null references public.discount_approvals(id);
