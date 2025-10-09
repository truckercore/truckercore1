-- 2025-09-16_nearest_truckstops_and_operator_keys.sql
-- Adds nearest_truckstops RPC and secure operator_api_keys storage (SHA-256 with per-key salt).
-- Also documents required envs for Edge Functions: OPERATOR_KEY_PEPPER.

begin;
set search_path = public;

-- 1) Nearest truckstops RPC (earthdistance)
create extension if not exists cube;
create extension if not exists earthdistance;

create or replace function public.nearest_truckstops(
  p_lat double precision,
  p_lng double precision,
  p_radius_km numeric,
  p_limit int default 200
) returns table(
  id uuid,
  lat double precision,
  lng double precision,
  dist_km numeric
)
language sql
stable
as $$
  select ts.id,
         ts.lat,
         ts.lng,
         (earth_distance(ll_to_earth(p_lat, p_lng), ll_to_earth(ts.lat, ts.lng)) / 1000.0)::numeric as dist_km
  from public.truckstops ts
  where earth_box(ll_to_earth(p_lat, p_lng), (p_radius_km * 1000.0)) @> ll_to_earth(ts.lat, ts.lng)
  order by earth_distance(ll_to_earth(p_lat, p_lng), ll_to_earth(ts.lat, ts.lng)) asc
  limit greatest(1, p_limit)
$$;

revoke all on function public.nearest_truckstops(double precision, double precision, numeric, int) from public;
grant execute on function public.nearest_truckstops(double precision, double precision, numeric, int) to authenticated, service_role;

-- 2) Operator API keys table (hash+salt, server pepper)
create table if not exists public.operator_api_keys (
  id uuid primary key default gen_random_uuid(),
  operator_org_id uuid not null,
  name text null,
  key_hash text not null,
  salt text not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid null
);

create index if not exists idx_operator_keys_org_active on public.operator_api_keys(operator_org_id, active);
create index if not exists idx_operator_keys_created_at on public.operator_api_keys(created_at desc);

comment on table public.operator_api_keys is 'Operator API keys stored as SHA-256(salt || plaintext || pepper). Plaintext shown once on creation only.';

-- RLS (optional: allow reads only to service role; no public reads)
alter table public.operator_api_keys enable row level security;
-- Deny by default; create a read policy for service_role only via role name check
create policy if not exists operator_keys_service_read on public.operator_api_keys
for select to authenticated
using (current_setting('role', true) = 'service_role');

commit;
