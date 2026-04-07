-- Seed default pricing plans (idempotent upserts)
-- Validate: select plan_id, audience, price_cents from public.pricing_plans where is_active = true order by audience, sort_order;

INSERT INTO public.pricing_plans (plan_id, audience, name, description, price_cents, currency, billing_interval, price_id, features, is_active, sort_order)
VALUES
  ('free',       'driver', 'Free',        'Basic usage with caps',                         0,    'USD', 'month', NULL, '{"caps":{"requests":50}}',  true,  10),
  ('pro_driver', 'driver', 'Pro Driver',  'Unlimited suggestions, higher caps',            999,  'USD', 'month', NULL, '{"caps":{"requests":1000}}', true,  20),
  ('pro_broker', 'broker', 'Pro Broker',  'Broker tools and analytics',                    14900,'USD', 'month', NULL, '{"features":["rank","analytics"]}', true,  30),
  ('pro_fleet',  'fleet',  'Pro Fleet',   'Up to 5 trucks; add-ons available',             9900, 'USD', 'month', NULL, '{"included_trucks":5}', true,  40),
  ('enterprise', 'org',    'Enterprise',  'Custom terms and SLAs',                         0,    'USD', 'month', NULL, '{"contact_sales":true}', true,  50)
ON CONFLICT (plan_id, audience) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  price_cents = EXCLUDED.price_cents,
  currency = EXCLUDED.currency,
  billing_interval = EXCLUDED.billing_interval,
  price_id = COALESCE(EXCLUDED.price_id, public.pricing_plans.price_id),
  features = EXCLUDED.features,
  is_active = EXCLUDED.is_active,
  sort_order = EXCLUDED.sort_order,
  updated_at = now();