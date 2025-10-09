-- Seed defaults (idempotent)
insert into public.ai_roi_baseline_defaults(key,value,comment) values
('fuel_price_usd_per_gal', 4.00, 'US avg fuel price'),
('hos_violation_cost_usd', 300.00, 'Avg soft+hard cost per violation')
on conflict (key) do nothing;
