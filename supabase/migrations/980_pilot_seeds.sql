-- Tenants
insert into public.orgs(id, name, plan) values
('00000000-0000-0000-0000-0000000AA001','Owner-Op Pilot','pro'),
('00000000-0000-0000-0000-0000000BB001','Fleet-20 Pilot','pro')
on conflict (id) do nothing;

-- Profiles (replace with your auth IDs where applicable)
-- Owner-Op: one driver
insert into public.profiles(user_id, org_id, role, app_is_premium)
values ('<OWNER_OP_USER_ID>','00000000-0000-0000-0000000AA001','owner_op', true)
on conflict (user_id) do update set org_id=excluded.org_id, role=excluded.role, app_is_premium=true;

-- Fleet-20: create 20 driver profiles (use your real IDs if available)
-- Demo synthetic UUIDs for data only; in practice invite users to attach real auth IDs
do $$ declare i int := 1; begin
  while i <= 20 loop
    insert into public.profiles(user_id, org_id, role, app_is_premium)
    values (gen_random_uuid(),'00000000-0000-0000-0000-0000000BB001','driver', true)
    on conflict do nothing;
    i := i + 1;
  end loop;
end $$;

-- Vehicles (1 + 20)
insert into public.vehicles(org_id, vin, plate, make, model, year, odo_miles)
select '00000000-0000-0000-0000-0000000AA001','VIN-OO-1','OO-001','Freightliner','Cascadia',2021, 250000
union all
select '00000000-0000-0000-0000-0000000BB001','VIN-FLT-'||i::text, 'FLT-'||LPAD(i::text,3,'0'),'Volvo','VNL',2020+ (i%3), 150000+i*1000
from generate_series(1,20) i
on conflict do nothing;

-- Loads near Dallas/Houston for optimizer demo (1000 rows)
insert into public.loads(id, origin_city, dest_city, pickup_lat, pickup_lng, miles, rate_usd)
select gen_random_uuid(), 'Dallas, TX', 'Random, US', 32.7 + (random()-0.5)*2.0, -96.8 + (random()-0.5)*2.0, 100 + (random()*1200), 600 + (random()*4000)
from generate_series(1,1000);

-- Promos
insert into public.discounts_promos(title,vendor,terms,min_tier,region)
values ('10¢/gal off','FuelCo','Valid Mon–Fri w/ loyalty app','free','TX')
on conflict do nothing;

-- Initial metrics + a couple IFTA records
insert into public.ifta_trips (org_id, driver_id, vehicle_id, started_at, ended_at, total_miles, state_miles)
select '00000000-0000-0000-0000-0000000AA001', (select user_id from public.profiles where org_id='00000000-0000-0000-0000-0000000AA001' limit 1), (select id from public.vehicles where org_id='00000000-0000-0000-0000000AA001' limit 1), now()-interval '8 hours', now()-interval '2 hours', 320.4, '{"TX":"300.4","OK":"20.0"}'
where not exists (select 1 from public.ifta_trips where org_id='00000000-0000-0000-0000-0000000AA001');

insert into public.ifta_fuel_purchases (org_id, vehicle_id, purchased_at, state, gallons, amount_usd, vendor)
select '00000000-0000-0000-0000-0000000AA001', (select id from public.vehicles where org_id='00000000-0000-0000-0000000AA001' limit 1), now(), 'TX', 50.250, 180.90, 'FuelCo'
where not exists (select 1 from public.ifta_fuel_purchases where org_id='00000000-0000-0000-0000000AA001');
