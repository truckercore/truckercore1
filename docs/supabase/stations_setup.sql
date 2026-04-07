-- Supabase stations table and realtime publication setup
-- Run this in your Supabase SQL editor.

-- 1) Create table (adjust types if needed)
create extension if not exists pgcrypto; -- for gen_random_uuid

create table if not exists public.stations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  lat double precision not null,
  lng double precision not null,
  open boolean not null default false,
  created_at timestamp with time zone default now()
);

-- 2) Add to realtime publication (required for Supabase Realtime)
-- New projects typically have `supabase_realtime` already created; if not, create it once:
-- create publication supabase_realtime for table public.stations;
-- Otherwise, add this table to the existing publication:
alter publication supabase_realtime add table public.stations;

-- 3) (Optional) Row Level Security and minimal policies
alter table public.stations enable row level security;

-- Policy examples (adapt to your auth model):
-- Allow authenticated read of stations
drop policy if exists stations_read on public.stations;
create policy stations_read on public.stations
  for select using (auth.role() = 'authenticated' or auth.role() = 'anon');

-- Allow service role or specific role to insert/update
-- Replace with your own conditions, or manage via PostgREST function
drop policy if exists stations_write on public.stations;
create policy stations_write on public.stations
  for insert with check (auth.role() = 'service_role')
  to authenticated;

drop policy if exists stations_update on public.stations;
create policy stations_update on public.stations
  for update using (auth.role() = 'service_role')
  to authenticated;

-- Note: For stricter control, remove 'to authenticated' and use service key or custom claims.
