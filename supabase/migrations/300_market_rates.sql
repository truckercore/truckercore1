-- Market rates stub (extend as needed)
create table if not exists public.market_rates (
  id uuid primary key default gen_random_uuid(),
  lane text not null, -- "DAL>ATL"
  ppm numeric(8,4) not null,
  updated_at timestamptz not null default now()
);
alter table public.market_rates enable row level security;
create policy market_rates_public_read on public.market_rates for select using (true);
