insert into public.orgs (id, name, plan)
values ('00000000-0000-0000-0000-000000000001','RoadDogg Demo Org','pro')
on conflict (id) do nothing;

-- Replace with your auth user id
insert into public.profiles (user_id, org_id, role, app_is_premium)
values ('<YOUR_AUTH_USER_ID>', '00000000-0000-0000-0000-000000000001','owner_op', true)
on conflict (user_id) do update set org_id=excluded.org_id, role=excluded.role, app_is_premium=true;

insert into public.vehicles (org_id, vin, plate, make, model, year, odo_miles)
values ('00000000-0000-0000-0000-000000000001','VINDEMO123','RDG-123','Freightliner','Cascadia',2021, 250000)
on conflict do nothing;

insert into public.discounts_promos (title,vendor,terms,min_tier,region)
values ('10¢/gal off','FuelCo','Valid Mon–Fri w/ loyalty app','free','TX')
on conflict do nothing;
