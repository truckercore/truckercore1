-- orgs, shipper accounts, tenders, quotes

create table if not exists public.orgs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  org_type text not null check (org_type in ('fleet','broker','shipper','3pl')),
  created_at timestamptz not null default now()
);

create table if not exists public.shipper_accounts (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id) on delete cascade,
  contact_name text,
  contact_email text,
  billing_currency text default 'USD',
  created_at timestamptz default now(),
  unique(org_id)
);

create table if not exists public.tenders (
  id uuid primary key default gen_random_uuid(),
  shipper_org_id uuid not null references public.orgs(id) on delete cascade,
  pickup_address jsonb not null,
  dropoff_address jsonb not null,
  commodity text,
  weight_kg numeric,
  equipment text,
  earliest_pickup timestamptz,
  latest_delivery timestamptz,
  notes text,
  status text default 'open' check (status in ('draft','open','quoted','awarded','in_transit','delivered','cancelled')),
  created_at timestamptz default now()
);

create table if not exists public.tender_quotes (
  id uuid primary key default gen_random_uuid(),
  tender_id uuid not null references public.tenders(id) on delete cascade,
  bidder_org_id uuid not null references public.orgs(id) on delete cascade,
  price_cents bigint not null,
  currency text default 'USD',
  eta_hours int,
  notes text,
  status text default 'proposed' check (status in ('proposed','accepted','declined')),
  created_at timestamptz default now(),
  unique(tender_id, bidder_org_id)
);

-- RLS
alter table public.orgs enable row level security;
alter table public.shipper_accounts enable row level security;
alter table public.tenders enable row level security;
alter table public.tender_quotes enable row level security;

-- Example policies (adjust claims to your JWT schema)
drop policy if exists orgs_read_own on public.orgs;
create policy orgs_read_own on public.orgs
for select using ((auth.jwt()->>'app_org_id')::uuid = id);

drop policy if exists tenders_rw_shipper on public.tenders;
create policy tenders_rw_shipper on public.tenders
for all using ((auth.jwt()->>'app_org_id')::uuid = shipper_org_id)
with check ((auth.jwt()->>'app_org_id')::uuid = shipper_org_id);

drop policy if exists quotes_rw_bidders on public.tender_quotes;
create policy quotes_rw_bidders on public.tender_quotes
for all using (
  (auth.jwt()->>'app_org_id')::uuid = bidder_org_id
  or (auth.jwt()->>'app_org_id')::uuid in (select shipper_org_id from public.tenders where id = tender_id)
)
with check ((auth.jwt()->>'app_org_id')::uuid = bidder_org_id);
