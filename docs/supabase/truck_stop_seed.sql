-- docs/supabase/truck_stop_seed.sql
-- Minimal multi-brand/multi-location seed for demos

-- Orgs
insert into orgs (org_id, name, slug) values
  ('00000000-0000-0000-0000-000000000001','RoadRanger','roadranger')
  on conflict (org_id) do nothing;
insert into orgs (org_id, name, slug) values
  ('00000000-0000-0000-0000-000000000002','FuelMax','fuelmax')
  on conflict (org_id) do nothing;

-- Locations
insert into locations (location_id, org_id, name, address, lat, lng, region, timezone) values
  ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','RR – I-80 Toledo','123 Hwy Rd, Toledo, OH',41.6528,-83.5379,'midwest','America/New_York'),
  ('10000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','RR – I-90 South Bend','45 Truck Ln, South Bend, IN',41.6764,-86.2520,'midwest','America/Chicago'),
  ('20000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002','FM – I-40 Amarillo','1 Route 66, Amarillo, TX',35.221997,-101.831299,'south','America/Chicago'),
  ('20000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000002','FM – I-5 Bakersfield','77 Depot St, Bakersfield, CA',35.3733,-119.0187,'west','America/Los_Angeles')
  on conflict (location_id) do nothing;

-- Fuel prices (effective now)
insert into fuel_prices (location_id, diesel_cents, discount_cents, effective_at, source) values
  ('10000000-0000-0000-0000-000000000001', 430, 10, now(), 'local'),
  ('10000000-0000-0000-0000-000000000002', 439, 0, now(), 'local'),
  ('20000000-0000-0000-0000-000000000001', 399, 5, now(), 'local'),
  ('20000000-0000-0000-0000-000000000002', 459, 20, now(), 'local')
  on conflict do nothing;

-- Promotions
insert into promotions (org_id, location_id, title, body, starts_at, ends_at, status)
values
  ('00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','Shower + Coffee','Free coffee with shower purchase', now(), now() + interval '7 days','active'),
  ('00000000-0000-0000-0000-000000000002',null,'Chain-wide Diesel Discount','$0.05 off with loyalty card', now(), now() + interval '14 days','active')
  on conflict do nothing;

-- Initial parking reports (operator & crowd)
insert into parking_status (location_id, source, available_spots, capacity, status, confidence, updated_by)
values
  ('10000000-0000-0000-0000-000000000001','operator', 20, 80, 'open', 0.9, null),
  ('10000000-0000-0000-0000-000000000001','crowd', 15, 80, 'limited', 0.6, null),
  ('20000000-0000-0000-0000-000000000001','operator', 5, 60, 'limited', 0.8, null)
  on conflict do nothing;

-- Seed user preferences (optional demo user)
insert into user_preferences (user_id, loyalty_brands, amenity_priority, detour_tolerance)
values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', array['RoadRanger'], '{"showers":0.9,"laundry":0.5}'::jsonb, 'normal')
on conflict (user_id) do nothing;

-- Kick initial compute
select fn_blend_parking_confidence('10000000-0000-0000-0000-000000000001');
select fn_compute_stop_score('10000000-0000-0000-0000-000000000001');
select fn_blend_parking_confidence('10000000-0000-0000-0000-000000000002');
select fn_compute_stop_score('10000000-0000-0000-0000-000000000002');
select fn_blend_parking_confidence('20000000-0000-0000-0000-000000000001');
select fn_compute_stop_score('20000000-0000-0000-0000-000000000001');
select fn_blend_parking_confidence('20000000-0000-0000-0000-000000000002');
select fn_compute_stop_score('20000000-0000-0000-0000-000000000002');
