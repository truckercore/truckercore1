-- IFTA trips and fuel purchases
create table if not exists public.ifta_trips (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id),
  driver_id uuid not null,
  vehicle_id uuid not null references public.vehicles(id),
  started_at timestamptz not null,
  ended_at timestamptz not null,
  total_miles numeric(10,1) not null,
  state_miles jsonb not null default '{}'::jsonb, -- {"TX":"100.0", ...}
  created_at timestamptz not null default now()
);
create index if not exists idx_ifta_trips_org_time on public.ifta_trips(org_id, started_at desc);
alter table public.ifta_trips enable row level security;
create policy ifta_trips_org_rw on public.ifta_trips
for all to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''))
with check (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

create table if not exists public.ifta_fuel_purchases (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id),
  vehicle_id uuid not null references public.vehicles(id),
  purchased_at timestamptz not null,
  state text not null,
  gallons numeric(10,3) not null,
  amount_usd numeric(12,2) not null,
  vendor text,
  created_at timestamptz not null default now()
);
create index if not exists idx_ifta_fuel_org_time on public.ifta_fuel_purchases(org_id, purchased_at desc);
alter table public.ifta_fuel_purchases enable row level security;
create policy ifta_fuel_org_rw on public.ifta_fuel_purchases
for all to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''))
with check (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

-- Quarterly rollup view (simple)
create or replace view public.ifta_quarterly as
select
  org_id,
  date_trunc('quarter', started_at)::date as quarter,
  jsonb_object_keys(state_miles) as state,
  sum((state_miles->>jsonb_object_keys(state_miles))::numeric) as miles,
  coalesce((
    select sum(gallons)
    from public.ifta_fuel_purchases f
    where f.org_id = t.org_id
      and date_trunc('quarter', f.purchased_at) = date_trunc('quarter', t.started_at)
      and f.state = jsonb_object_keys(t.state_miles)
  ), 0) as gallons
from public.ifta_trips t
group by 1,2,3;

-- Function to produce CSV rows for Edge function
create or replace function public.ifta_quarter_csv(org uuid, quarter_date date)
returns table(state text, miles numeric, gallons numeric)
language sql
stable
as $$
  select state, miles, gallons
  from public.ifta_quarterly
  where org_id = org
    and quarter = date_trunc('quarter', quarter_date)::date
  order by state
$$;
grant select on public.ifta_quarterly to authenticated;
grant execute on function public.ifta_quarter_csv(uuid, date) to authenticated;
