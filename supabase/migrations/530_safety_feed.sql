-- Weigh station status stub for public read
create table if not exists public.weigh_station_status (
  id uuid primary key default gen_random_uuid(),
  station_name text not null,
  state text not null,
  status text not null check (status in ('open','closed','delayed','unknown')),
  observed_at timestamptz not null default now()
);
alter table public.weigh_station_status enable row level security;
create policy weigh_station_public_read on public.weigh_station_status for select using (true);
