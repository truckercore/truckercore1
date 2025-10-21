-- Demo seed for TruckerCore fleet/dispatch schema
-- Safe to run multiple times (guards used). Assumes base schema is applied.

-- Configure demo carrier/org id
with const as (
  select '00000000-0000-0000-0000-0000000000A1'::uuid as carrier_id
), upsert_trucks as (
  insert into public.trucks (id, external_id, plate, make, model, year, status, carrier_id)
  select gen_random_uuid(), 'TRK-001', 'ABC123', 'Volvo', 'VNL', 2020, 'available', const.carrier_id from const
  where not exists (select 1 from public.trucks t where t.external_id = 'TRK-001' and t.carrier_id = (select carrier_id from const))
  returning id as truck1_id
), upsert_truck2 as (
  insert into public.trucks (id, external_id, plate, make, model, year, status, carrier_id)
  select gen_random_uuid(), 'TRK-002', 'XYZ789', 'Freightliner', 'Cascadia', 2019, 'available', (select carrier_id from const)
  where not exists (select 1 from public.trucks t where t.external_id = 'TRK-002' and t.carrier_id = (select carrier_id from const))
  returning id as truck2_id
), upsert_truck3 as (
  insert into public.trucks (id, external_id, plate, make, model, year, status, carrier_id)
  select gen_random_uuid(), 'TRK-003', 'LMN456', 'Peterbilt', '579', 2021, 'available', (select carrier_id from const)
  where not exists (select 1 from public.trucks t where t.external_id = 'TRK-003' and t.carrier_id = (select carrier_id from const))
  returning id as truck3_id
)
select 1;

-- Create one demo driver and assign to TRK-001 (if drivers table exists)
with const as (
  select '00000000-0000-0000-0000-0000000000A1'::uuid as carrier_id
), drv as (
  insert into public.drivers (full_name, phone, email, carrier_id)
  values ('Alex Demo', '+1-555-0101', 'alex.demo@example.com', (select carrier_id from const))
  on conflict do nothing
  returning id
), did as (
  select id from drv
  union all
  select d.id from public.drivers d where d.full_name = 'Alex Demo' and d.carrier_id = (select carrier_id from const) limit 1
)
update public.trucks t
set driver_id = (select id from did)
where t.external_id = 'TRK-001' and t.carrier_id = (select carrier_id from const);

-- Create one dispatch order with multiple legs (Seattle -> Portland -> Eugene)
with const as (
  select '00000000-0000-0000-0000-0000000000A1'::uuid as carrier_id
), order_ins as (
  insert into public.dispatch_orders (external_number, status, priority, carrier_id, planned_start_at, planned_end_at, notes)
  values ('DO-1001','released', 10, (select carrier_id from const), now(), now() + interval '1 day', 'Demo order with multiple legs')
  on conflict do nothing
  returning id
), order_id as (
  select id from order_ins
  union all
  select o.id from public.dispatch_orders o where o.external_number = 'DO-1001' and o.carrier_id = (select carrier_id from const) limit 1
), legs as (
  insert into public.dispatch_order_legs (order_id, seq, type, lat, lng, address, window_start, window_end)
  select (select id from order_id), 1, 'pickup', 47.6062, -122.3321, 'Seattle, WA', now(), now() + interval '2 hour'
  where not exists (select 1 from public.dispatch_order_legs l where l.order_id = (select id from order_id) and l.seq = 1)
  returning 1 as ok
)
insert into public.dispatch_order_legs (order_id, seq, type, lat, lng, address, window_start, window_end)
select (select id from order_id), 2, 'dropoff', 45.5152, -122.6784, 'Portland, OR', now() + interval '6 hour', now() + interval '10 hour'
where not exists (select 1 from public.dispatch_order_legs l where l.order_id = (select id from order_id) and l.seq = 2);

insert into public.dispatch_order_legs (order_id, seq, type, lat, lng, address, window_start, window_end)
select (select id from order_id), 3, 'dropoff', 44.0521, -123.0868, 'Eugene, OR', now() + interval '12 hour', now() + interval '16 hour'
where not exists (select 1 from public.dispatch_order_legs l where l.order_id = (select id from order_id) and l.seq = 3);

-- Assign TRK-001 to the order
with t as (
  select id from public.trucks where external_id = 'TRK-001' and carrier_id = '00000000-0000-0000-0000-0000000000A1'::uuid
), o as (
  select id from public.dispatch_orders where external_number = 'DO-1001' and carrier_id = '00000000-0000-0000-0000-0000000000A1'::uuid
)
insert into public.assignments (truck_id, order_id, status, notes)
select (select id from t), (select id from o), 'assigned', 'Demo assignment'
where not exists (
  select 1 from public.assignments a where a.truck_id = (select id from t) and a.order_id = (select id from o)
);

-- Seed telemetry for TRK-001 along the route
with t as (
  select id from public.trucks where external_id = 'TRK-001' and carrier_id = '00000000-0000-0000-0000-0000000000A1'::uuid
)
insert into public.truck_positions (truck_id, lat, lng, speed_kph, heading_deg, odometer_km, gps_ts, source)
values
((select id from t), 47.6101, -122.3421, 50, 180, 10000.0, now() - interval '30 min', 'seed'),
((select id from t), 46.8523, -121.7603, 80, 190, 10050.5, now() - interval '20 min', 'seed'),
((select id from t), 45.5152, -122.6784, 10, 200, 10100.0, now() - interval '10 min', 'seed')
on conflict do nothing;

-- Optional geofence seed (only runs if geofences table exists)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='geofences'
  ) THEN
    -- A simple rough rectangle around downtown Portland
    insert into public.geofences (carrier_id, name, area, kind)
    values (
      '00000000-0000-0000-0000-0000000000A1'::uuid,
      'Portland Downtown',
      ST_GeogFromText('POLYGON((
        -122.6860 45.5280,
        -122.6860 45.5000,
        -122.6500 45.5000,
        -122.6500 45.5280,
        -122.6860 45.5280
      ))'),
      'city'
    )
    on conflict do nothing;
  END IF;
END $$;
