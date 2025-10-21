-- Fleet and Dispatch Schema for TruckerCore (Supabase/Postgres)
-- Run this in your Supabase SQL editor.
-- This script defines tables for trucks, truck position history, current positions, assignments, and dispatch orders.
-- It follows conventions similar to stations_setup.sql and is safe to run multiple times (IF NOT EXISTS guards).

-- 0) Prerequisites
create extension if not exists pgcrypto; -- for gen_random_uuid()
-- PostGIS is optional; base schema uses plain lat/lng. See docs/supabase/fleet_postgis_migration.sql for enabling PostGIS.

-- 1) Enum types
-- Truck status across high-level lifecycle
create type public.truck_status as enum ('inactive','available','en_route','at_stop','maintenance','offline')
  |
  -- if enum exists, do nothing
  (select null where exists (
    select 1 from pg_type t where t.typname = 'truck_status'
  ));
-- Note: The above trick may not work on all Postgres versions. If your project already has enums, skip creating if present.
-- To avoid errors on re-run, we wrap enum creation in DO blocks below.

-- Safe enum creation blocks
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'assignment_status') THEN
    CREATE TYPE public.assignment_status AS ENUM ('planned','assigned','en_route','at_pickup','at_dropoff','completed','canceled');
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'dispatch_order_status') THEN
    CREATE TYPE public.dispatch_order_status AS ENUM ('draft','released','in_progress','completed','canceled');
  END IF;
END $$;

-- 2) Core reference tables
create table if not exists public.trucks (
  id uuid primary key default gen_random_uuid(),
  external_id text,                 -- carrier/telematics id if any
  vin text,                          -- vehicle identification number
  plate text,
  make text,
  model text,
  year int,
  status public.truck_status default 'available',
  driver_id uuid,                    -- current assigned driver (nullable)
  carrier_id uuid,                   -- owning carrier/company id (if multi-tenant)
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_trucks_status on public.trucks(status);
create index if not exists idx_trucks_carrier on public.trucks(carrier_id);

-- Minimal drivers table (tenant-scoped). If you already have one, remove this block.
create table if not exists public.drivers (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  phone text,
  email text,
  status text default 'active',
  carrier_id uuid not null,
  created_at timestamptz not null default now()
);
create index if not exists idx_drivers_carrier on public.drivers(carrier_id);

alter table public.drivers enable row level security;
drop policy if exists drivers_tenant_select on public.drivers;
create policy drivers_tenant_select on public.drivers
  for select using ((auth.jwt() ->> 'org_id')::uuid = carrier_id);
drop policy if exists drivers_tenant_insert on public.drivers;
create policy drivers_tenant_insert on public.drivers
  for insert with check ((auth.jwt() ->> 'org_id')::uuid = carrier_id);
drop policy if exists drivers_tenant_update on public.drivers;
create policy drivers_tenant_update on public.drivers
  for update using ((auth.jwt() ->> 'org_id')::uuid = carrier_id);

-- Link trucks.driver_id to drivers if present
alter table public.trucks
  add constraint if not exists fk_trucks_driver foreign key (driver_id) references public.drivers(id) on delete set null;

-- 3) Truck position history (telemetry)
-- Stores chronological positions for each truck. Base schema uses plain lat/lng.
create table if not exists public.truck_positions (
  id uuid primary key default gen_random_uuid(),
  truck_id uuid not null references public.trucks(id) on delete cascade,
  lat double precision not null,
  lng double precision not null,
  speed_kph double precision,               -- instantaneous speed
  heading_deg double precision,             -- 0-360
  accuracy_m double precision,              -- optional GPS accuracy in meters
  odometer_km double precision,
  gps_ts timestamptz not null,              -- timestamp from device
  source text,                               -- telemetry source/provider name
  trip_id uuid,                              -- optional foreign key to trip/order (nullable)
  created_at timestamptz not null default now()
);

create index if not exists idx_truck_positions_truck_ts on public.truck_positions(truck_id, gps_ts desc);

-- 4) Current positions (materialized table maintained via upsert trigger)
-- Keeps the latest position per truck for quick reads and Realtime streams.
create table if not exists public.truck_current_positions (
  truck_id uuid primary key references public.trucks(id) on delete cascade,
  lat double precision not null,
  lng double precision not null,
  speed_kph double precision,
  heading_deg double precision,
  accuracy_m double precision,
  odometer_km double precision,
  gps_ts timestamptz not null,
  updated_at timestamptz not null default now()
);

-- Upsert function: when a new truck_positions row arrives, update the current entry only if newer
create or replace function public.fn_upsert_current_truck_position() returns trigger as $$
begin
  -- Only update if incoming gps_ts is newer or current row absent
  insert into public.truck_current_positions as cp (
    truck_id, lat, lng, speed_kph, heading_deg, accuracy_m, odometer_km, gps_ts
  ) values (
    new.truck_id, new.lat, new.lng, new.speed_kph, new.heading_deg, new.accuracy_m, new.odometer_km, new.gps_ts
  )
  on conflict (truck_id) do update
    set lat = excluded.lat,
        lng = excluded.lng,
        speed_kph = excluded.speed_kph,
        heading_deg = excluded.heading_deg,
        accuracy_m = excluded.accuracy_m,
        odometer_km = excluded.odometer_km,
        gps_ts = excluded.gps_ts,
        updated_at = now()
  where cp.gps_ts is null or excluded.gps_ts > cp.gps_ts;
  return null;
end;
$$ language plpgsql;

-- Trigger on insert into history to maintain current
create trigger trg_upsert_current_truck_position
  after insert on public.truck_positions
  for each row execute function public.fn_upsert_current_truck_position();

-- 5) Dispatch Orders
-- Header that groups one or more legs/line items to be executed, for a truck or to be assigned later.
create table if not exists public.dispatch_orders (
  id uuid primary key default gen_random_uuid(),
  external_number text,                         -- human-friendly order number
  status public.dispatch_order_status not null default 'draft',
  priority int default 0,                       -- higher number = higher priority
  carrier_id uuid,                              -- for multi-tenant partitioning
  planned_start_at timestamptz,
  planned_end_at timestamptz,
  notes text,
  created_by uuid,                              -- user id
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_dispatch_orders_status on public.dispatch_orders(status);
create index if not exists idx_dispatch_orders_carrier on public.dispatch_orders(carrier_id);

-- 5a) Dispatch order legs (pickup/dropoff waypoints, sequence)
create table if not exists public.dispatch_order_legs (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.dispatch_orders(id) on delete cascade,
  seq int not null,                              -- 1..n
  type text not null check (type in ('pickup','dropoff','stop','break')),
  lat double precision not null,
  lng double precision not null,
  address text,
  window_start timestamptz,
  window_end timestamptz,
  notes text,
  created_at timestamptz not null default now()
);

create unique index if not exists uq_dispatch_order_legs_order_seq on public.dispatch_order_legs(order_id, seq);

-- 6) Assignments (bind trucks/drivers to orders or legs)
create table if not exists public.assignments (
  id uuid primary key default gen_random_uuid(),
  truck_id uuid not null references public.trucks(id) on delete restrict,
  driver_id uuid,                                -- optional explicit driver tie
  order_id uuid references public.dispatch_orders(id) on delete set null,
  leg_id uuid references public.dispatch_order_legs(id) on delete set null,
  status public.assignment_status not null default 'planned',
  assigned_at timestamptz default now(),
  started_at timestamptz,
  completed_at timestamptz,
  canceled_at timestamptz,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint chk_assignment_leg_order_consistency
    check (leg_id is null or (order_id is not null))
);

create index if not exists idx_assignments_truck_status on public.assignments(truck_id, status);
create index if not exists idx_assignments_order on public.assignments(order_id);
create index if not exists idx_assignments_leg on public.assignments(leg_id);

-- Optional FKs to drivers table if present
-- alter table public.assignments add constraint fk_assignments_driver foreign key (driver_id) references public.drivers(id);

-- 7) Quality-of-life views
-- Current truck operational snapshot combining truck, current position, and most relevant assignment (latest non-final)
create or replace view public.v_truck_current as
select
  t.id as truck_id,
  t.external_id,
  t.vin,
  t.plate,
  t.status as truck_status,
  cp.lat,
  cp.lng,
  cp.speed_kph,
  cp.heading_deg,
  cp.gps_ts,
  a.id as assignment_id,
  a.status as assignment_status,
  a.order_id,
  a.leg_id
from public.trucks t
left join public.truck_current_positions cp on cp.truck_id = t.id
left join lateral (
  select a1.*
  from public.assignments a1
  where a1.truck_id = t.id and a1.status in ('planned','assigned','en_route','at_pickup','at_dropoff')
  order by coalesce(a1.started_at, a1.assigned_at) desc
  limit 1
) a on true;

-- 8) Realtime publication (for Supabase Realtime streaming)
-- Ensure these tables are included in the realtime publication.
-- If publication doesn't exist, uncomment next line to create it for the first time:
-- create publication supabase_realtime for table public.trucks, public.truck_positions, public.truck_current_positions, public.dispatch_orders, public.dispatch_order_legs, public.assignments;
-- Otherwise, add tables to existing publication:
alter publication supabase_realtime add table public.trucks;
alter publication supabase_realtime add table public.truck_positions;
alter publication supabase_realtime add table public.truck_current_positions;
alter publication supabase_realtime add table public.dispatch_orders;
alter publication supabase_realtime add table public.dispatch_order_legs;
alter publication supabase_realtime add table public.assignments;

-- 9) Row Level Security (enable, tenant-aware using auth.jwt()->>'org_id')
alter table public.trucks enable row level security;
alter table public.truck_positions enable row level security;
alter table public.truck_current_positions enable row level security;
alter table public.dispatch_orders enable row level security;
alter table public.dispatch_order_legs enable row level security;
alter table public.assignments enable row level security;

-- Tenant-scoped SELECT policies (carrier_id must match token org_id)
drop policy if exists trucks_tenant_select on public.trucks;
create policy trucks_tenant_select on public.trucks
  for select using ((auth.jwt() ->> 'org_id')::uuid = carrier_id);
drop policy if exists truck_positions_tenant_select on public.truck_positions;
create policy truck_positions_tenant_select on public.truck_positions
  for select using ((auth.jwt() ->> 'org_id')::uuid = (select carrier_id from public.trucks t where t.id = truck_positions.truck_id));
drop policy if exists truck_current_positions_tenant_select on public.truck_current_positions;
create policy truck_current_positions_tenant_select on public.truck_current_positions
  for select using ((auth.jwt() ->> 'org_id')::uuid = (select carrier_id from public.trucks t where t.id = truck_current_positions.truck_id));
drop policy if exists dispatch_orders_tenant_select on public.dispatch_orders;
create policy dispatch_orders_tenant_select on public.dispatch_orders
  for select using ((auth.jwt() ->> 'org_id')::uuid = carrier_id);
drop policy if exists dispatch_order_legs_tenant_select on public.dispatch_order_legs;
create policy dispatch_order_legs_tenant_select on public.dispatch_order_legs
  for select using ((auth.jwt() ->> 'org_id')::uuid = (select carrier_id from public.dispatch_orders o where o.id = dispatch_order_legs.order_id));
drop policy if exists assignments_tenant_select on public.assignments;
create policy assignments_tenant_select on public.assignments
  for select using ((auth.jwt() ->> 'org_id')::uuid = (select carrier_id from public.trucks t where t.id = assignments.truck_id));

-- Tenant-scoped INSERT/UPDATE (replace or extend as needed)
drop policy if exists trucks_tenant_insert on public.trucks;
create policy trucks_tenant_insert on public.trucks
  for insert with check ((auth.jwt() ->> 'org_id')::uuid = carrier_id);
drop policy if exists trucks_tenant_update on public.trucks;
create policy trucks_tenant_update on public.trucks
  for update using ((auth.jwt() ->> 'org_id')::uuid = carrier_id);

drop policy if exists truck_positions_tenant_insert on public.truck_positions;
create policy truck_positions_tenant_insert on public.truck_positions
  for insert with check ((auth.jwt() ->> 'org_id')::uuid = (select carrier_id from public.trucks t where t.id = truck_id));

drop policy if exists dispatch_orders_tenant_insert on public.dispatch_orders;
create policy dispatch_orders_tenant_insert on public.dispatch_orders
  for insert with check ((auth.jwt() ->> 'org_id')::uuid = carrier_id);
drop policy if exists dispatch_orders_tenant_update on public.dispatch_orders;
create policy dispatch_orders_tenant_update on public.dispatch_orders
  for update using ((auth.jwt() ->> 'org_id')::uuid = carrier_id);

drop policy if exists assignments_tenant_insert on public.assignments;
create policy assignments_tenant_insert on public.assignments
  for insert with check ((auth.jwt() ->> 'org_id')::uuid = (select carrier_id from public.trucks t where t.id = truck_id));
drop policy if exists assignments_tenant_update on public.assignments;
create policy assignments_tenant_update on public.assignments
  for update using ((auth.jwt() ->> 'org_id')::uuid = (select carrier_id from public.trucks t where t.id = assignments.truck_id));

-- 9a) RPC for validated telemetry ingestion (attach org, throttle by timestamp)
create or replace function public.fn_ingest_truck_position(
  p_truck_id uuid,
  p_lat double precision,
  p_lng double precision,
  p_speed_kph double precision,
  p_heading_deg double precision,
  p_odometer_km double precision,
  p_gps_ts timestamptz,
  p_source text
) returns void as $$
begin
  -- Ensure the caller belongs to the same org/carrier as the truck
  if not exists (
    select 1 from public.trucks t
    where t.id = p_truck_id and t.carrier_id = (auth.jwt() ->> 'org_id')::uuid
  ) then
    raise exception 'not authorized for this truck';
  end if;

  -- Basic throttle: only accept if not older than current gps_ts for that truck
  perform 1 from public.truck_current_positions cp
   where cp.truck_id = p_truck_id and cp.gps_ts >= p_gps_ts;
  if found then
    return; -- drop older/no-op updates
  end if;

  insert into public.truck_positions(truck_id, lat, lng, speed_kph, heading_deg, accuracy_m, odometer_km, gps_ts, source)
  values (p_truck_id, p_lat, p_lng, p_speed_kph, p_heading_deg, null, p_odometer_km, p_gps_ts, coalesce(p_source,'rpc'));
end;
$$ language plpgsql security definer;

-- Allow authenticated to call RPC; RLS inside will handle tenant checks
revoke all on function public.fn_ingest_truck_position(uuid,double precision,double precision,double precision,double precision,double precision,timestamptz,text) from public;
grant execute on function public.fn_ingest_truck_position(uuid,double precision,double precision,double precision,double precision,double precision,timestamptz,text) to authenticated;

-- 9b) Dispatch workflow: stops, events, ETA/routing, notifications
-- Stops table captures planned vs actual arrivals/departures per leg
create table if not exists public.dispatch_stops (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.dispatch_orders(id) on delete cascade,
  leg_id uuid references public.dispatch_order_legs(id) on delete set null,
  seq int not null,
  kind text not null check (kind in ('pickup','dropoff','stop','break')),
  lat double precision not null,
  lng double precision not null,
  address text,
  planned_window_start timestamptz,
  planned_window_end timestamptz,
  planned_eta timestamptz,
  planned_distance_km double precision,
  routing_provider text,
  status text not null default 'planned', -- planned, en_route, at_stop, completed, canceled
  actual_arrival_at timestamptz,
  actual_departure_at timestamptz,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists uq_dispatch_stops_order_seq on public.dispatch_stops(order_id, seq);

-- Events audit log for dispatch lifecycle
create table if not exists public.dispatch_events (
  id uuid primary key default gen_random_uuid(),
  order_id uuid references public.dispatch_orders(id) on delete cascade,
  assignment_id uuid references public.assignments(id) on delete set null,
  stop_id uuid references public.dispatch_stops(id) on delete set null,
  event_type text not null, -- assigned, accepted, rejected, started, arrived, departed, completed, canceled, note, photo
  actor_user_id uuid,
  actor_role text,
  lat double precision,
  lng double precision,
  details jsonb,
  created_at timestamptz not null default now()
);

-- Outbox for notifications (push/email) to be processed by an Edge Function/worker
create table if not exists public.notification_outbox (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('push','email')),
  recipient text not null, -- device token or email
  subject text,
  body text,
  payload jsonb,
  status text not null default 'pending', -- pending, sent, failed
  error text,
  created_at timestamptz not null default now(),
  sent_at timestamptz
);

-- RLS for new tables (tenant via joins)
alter table public.dispatch_stops enable row level security;
alter table public.dispatch_events enable row level security;
alter table public.notification_outbox enable row level security;

drop policy if exists dispatch_stops_tenant_select on public.dispatch_stops;
create policy dispatch_stops_tenant_select on public.dispatch_stops
  for select using ((auth.jwt() ->> 'org_id')::uuid = (select carrier_id from public.dispatch_orders o where o.id = dispatch_stops.order_id));
drop policy if exists dispatch_stops_tenant_cud on public.dispatch_stops;
create policy dispatch_stops_tenant_cud on public.dispatch_stops
  for all using ((auth.jwt() ->> 'org_id')::uuid = (select carrier_id from public.dispatch_orders o where o.id = dispatch_stops.order_id))
  with check ((auth.jwt() ->> 'org_id')::uuid = (select carrier_id from public.dispatch_orders o where o.id = dispatch_stops.order_id));

drop policy if exists dispatch_events_tenant_select on public.dispatch_events;
create policy dispatch_events_tenant_select on public.dispatch_events
  for select using (
    (order_id is not null and (auth.jwt() ->> 'org_id')::uuid = (select carrier_id from public.dispatch_orders o where o.id = dispatch_events.order_id))
    or
    (assignment_id is not null and (auth.jwt() ->> 'org_id')::uuid = (select t.carrier_id from public.assignments a join public.trucks t on t.id = a.truck_id where a.id = dispatch_events.assignment_id))
  );
drop policy if exists dispatch_events_tenant_insert on public.dispatch_events;
create policy dispatch_events_tenant_insert on public.dispatch_events
  for insert with check (
    (order_id is not null and (auth.jwt() ->> 'org_id')::uuid = (select carrier_id from public.dispatch_orders o where o.id = order_id))
    or
    (assignment_id is not null and (auth.jwt() ->> 'org_id')::uuid = (select t.carrier_id from public.assignments a join public.trucks t on t.id = a.truck_id where a.id = assignment_id))
  );

-- Realtime add-ons
alter publication supabase_realtime add table public.dispatch_stops;
alter publication supabase_realtime add table public.dispatch_events;

-- 10) Notes
-- - Base schema uses lat/lng. For PostGIS and geofencing, apply docs/supabase/fleet_postgis_migration.sql.
-- - truck_current_positions is maintained automatically by trigger on inserts to truck_positions.
-- - For upserts from telemetry, insert into truck_positions; do not write directly to current table.
-- - If you prefer a view-only current position, you can replace the table+trigger with a view using DISTINCT ON by gps_ts per truck; the table approach is faster for frequent reads and Realtime.
-- - RLS policies assume a JWT claim 'org_id' of type uuid. Adjust if your claim key differs.
