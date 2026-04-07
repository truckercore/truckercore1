-- docs/sql/rls_fixtures.sql
-- Seed minimal fixtures for cross-tenant RLS simulation in non-prod

-- Orgs
insert into public.orgs (id, name, org_type) values
  ('00000000-0000-0000-0000-00000000a001','Org A','fleet')
on conflict do nothing;
insert into public.orgs (id, name, org_type) values
  ('00000000-0000-0000-0000-00000000b001','Org B','fleet')
on conflict do nothing;

-- Users (if auth.users exists in this environment, otherwise ignore errors)
-- Note: Some environments restrict writes to auth.users; wrap in try/ignore when applying.
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000d001','driverA@example.com')
on conflict do nothing;
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000f001','fleetA@example.com')
on conflict do nothing;
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000d002','driverB@example.com')
on conflict do nothing;

-- Membership (example table: fleet_members(org_id,user_id,role))
insert into public.fleet_members (org_id, user_id, role) values
  ('00000000-0000-0000-0000-00000000a001','00000000-0000-0000-0000-00000000d001','driver'),
  ('00000000-0000-0000-0000-00000000a001','00000000-0000-0000-0000-00000000f001','fleet_manager'),
  ('00000000-0000-0000-0000-00000000b001','00000000-0000-0000-0000-00000000d002','driver')
on conflict do nothing;

-- Data rows for leakage tests (example: ownerop_expenses)
insert into public.ownerop_expenses (org_id, user_id, category, amount_usd, incurred_on)
values
  ('00000000-0000-0000-0000-00000000a001','00000000-0000-0000-0000-00000000d001','fuel', 123.45, current_date - 1),
  ('00000000-0000-0000-0000-00000000b001','00000000-0000-0000-0000-00000000d002','fuel', 234.56, current_date - 1)
on conflict do nothing;

-- Optional: more tables commonly RLS-scoped
-- public.hos_logs
insert into public.hos_logs (id, org_id, driver_user_id, start_time, end_time, status)
values
  ('11111111-1111-1111-1111-11111111a001','00000000-0000-0000-0000-00000000a001','00000000-0000-0000-0000-00000000d001', now()-interval '2h', now()-interval '1h', 'driving')
on conflict do nothing;

-- public.inspection_reports
insert into public.inspection_reports (id, org_id, driver_user_id, vehicle_id, type, signed_at)
values
  ('22222222-2222-2222-2222-22222222a001','00000000-0000-0000-0000-00000000a001','00000000-0000-0000-0000-00000000d001','33333333-3333-3333-3333-33333333a001','pre_trip', now()-interval '1d')
on conflict do nothing;
