-- docs/supabase/promo_seed.sql
-- Minimal seed data for promotions demo

-- Assumes orgs, locations, and profiles exist. Replace UUIDs accordingly.
-- Example placeholders (update in your project):
-- select org_id, name from orgs limit 1;
-- select location_id, name from locations limit 5;

insert into promotions (org_id, title, description, type, value_cents, start_at, end_at, channels, is_active)
values (
  (select org_id from orgs limit 1),
  '10% off Diesel',
  'Limited-time discount for loyal drivers',
  'percent',
  1000,
  now() - interval '1 day',
  now() + interval '30 day',
  '{QR,code}',
  true
) returning id;

-- Optional static code for POS fallback
insert into promo_codes (promo_id, code, max_uses, is_active)
select id, 'DIESEL10', 1000, true from promotions order by id desc limit 1;
