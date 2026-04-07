begin;

create table if not exists public.loads (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,                        -- posting fleet/shipper
  broker_id uuid,                              -- optional broker org
  posted_by uuid not null,                     -- user posting
  origin text not null,
  destination text not null,
  equipment text not null,
  weight_lb int,
  price_offer_usd numeric,
  status text not null default 'open' check (status in ('open','matched','completed','cancelled')),
  created_at timestamptz not null default now()
);

create index if not exists idx_loads_org_status on public.loads(org_id, status);
create index if not exists idx_loads_created on public.loads(created_at desc);

create table if not exists public.load_bids (
  id uuid primary key default gen_random_uuid(),
  load_id uuid not null references public.loads(id) on delete cascade,
  bidder_org uuid not null,
  bidder_user uuid not null,
  bid_price_usd numeric not null,
  status text not null default 'pending' check (status in ('pending','accepted','rejected')),
  created_at timestamptz not null default now()
);

create index if not exists idx_bids_load on public.load_bids(load_id);
create index if not exists idx_bids_org_time on public.load_bids(bidder_org, created_at desc);

create table if not exists public.load_transactions (
  id uuid primary key default gen_random_uuid(),
  load_id uuid not null references public.loads(id) on delete cascade,
  payer_org uuid not null,
  payee_org uuid not null,
  amount_cents int not null check (amount_cents > 0),
  status text not null default 'pending' check (status in ('pending','paid','failed')),
  created_at timestamptz not null default now()
);

create index if not exists idx_txn_load on public.load_transactions(load_id);
create index if not exists idx_txn_status on public.load_transactions(status);

-- RLS
alter table public.loads enable row level security;
alter table public.load_bids enable row level security;
alter table public.load_transactions enable row level security;

-- Read: authenticated users can read public marketplace rows (adjust if needed)
create policy if not exists loads_read_all on public.loads
for select to authenticated
using (true);

-- Post: only users in their org (org_id = jwt.app_org_id). posted_by must match caller
create policy if not exists loads_insert_org on public.loads
for insert to authenticated
with check (
  org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','')
);

-- Bids: bidder_org must match caller org
create policy if not exists bids_insert_org on public.load_bids
for insert to authenticated
with check (
  bidder_org::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','')
);

-- Bids read: allow authenticated to read bids for loads they posted or bids by their org
create policy if not exists bids_read_scoped on public.load_bids
for select to authenticated
using (
  bidder_org::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','')
  or load_id in (select id from public.loads where org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''))
);

-- Transactions: read scoped to payer or payee org; writes via service role only
create policy if not exists txn_read_org on public.load_transactions
for select to authenticated
using (
  payer_org::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','')
  or payee_org::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','')
);

commit;
