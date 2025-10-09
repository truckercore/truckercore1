-- Phase 4 seed data (Stage)
-- Replace placeholders <ORG_UUID>, <OWNER_USER_UUID>, <DRIVER_USER_UUID>, <VEH_UUID>

insert into public.analytics_snapshots (org_id, date_bucket, scope, total_loads, total_miles, revenue_usd, cost_usd, avg_ppm, on_time_pct)
values ('<ORG_UUID>', (current_date - 1), 'fleet', 12, 4680.0, 10230.00, 4100.00, 2.1875, 94.50)
on conflict (org_id, date_bucket, scope) do nothing;

insert into public.ownerop_expenses (org_id, user_id, category, amount_usd, miles, incurred_on)
values ('<ORG_UUID>', '<OWNER_USER_UUID>', 'fuel', 350.00, 600.0, current_date);

insert into public.hos_logs (org_id, driver_user_id, start_time, end_time, status)
values ('<ORG_UUID>', '<DRIVER_USER_UUID>', now() - interval '5h', now() - interval '3h', 'driving');

insert into public.inspection_reports (org_id, driver_user_id, vehicle_id, type, defects, certified_safe, signed_at)
values (
  '<ORG_UUID>',
  '<DRIVER_USER_UUID>',
  '<VEH_UUID>',
  'pre_trip',
  '[{"component":"brakes","severity":"minor"}]'::jsonb,
  true,
  now()
);
