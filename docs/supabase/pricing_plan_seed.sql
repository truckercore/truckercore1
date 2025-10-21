-- docs/supabase/pricing_plan_seed.sql
-- Seed plan_catalog with three tiers and simple limits JSON.
-- Non-destructive: uses upsert on price_id when possible. Adjust price_id values to your Stripe prices.

create table if not exists plan_catalog (
  price_id text primary key,
  plan text not null check (plan in ('free','premium','enterprise')),
  name text not null,
  features jsonb not null default '{}'::jsonb,
  limits jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function plan_catalog_touch() returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end; $$;

drop trigger if exists t_plan_catalog_touch on plan_catalog;
create trigger t_plan_catalog_touch before update on plan_catalog
for each row execute function plan_catalog_touch();

-- NOTE: Replace the placeholder price_XXX with your Stripe price IDs.
insert into plan_catalog(price_id, plan, name, features, limits)
values
  ('price_FREE_PLACEHOLDER','free','Free (Single Location Starter)',
    jsonb_build_object(
      'promos_basic', true,
      'qr_static', true,
      'manual_codes', true,
      'scanner_webcam', true,
      'analytics_basic', true
    ),
    jsonb_build_object(
      'seats', 2,
      'locations', 1,
      'data_retention_days', 30
    )
  ),
  ('price_PREMIUM_PLACEHOLDER','premium','Premium (Multi-Location Growth)',
    jsonb_build_object(
      'promos_rules_engine', true,
      'targeting_chain_regional', true,
      'wallet_saves', true,
      'qr_ephemeral_tokens', true,
      'parking_iot_confidence_fusion', true,
      'fuel_scheduling_competitiveness', true,
      'scanner_pos_shortcode', true,
      'analytics_funnel_heatmaps_segments', true,
      'webhooks_pos_erp_hmac', true
    ),
    jsonb_build_object(
      'seats', 20,
      'locations', 25,
      'data_retention_days', 180
    )
  ),
  ('price_ENTERPRISE_PLACEHOLDER','enterprise','Enterprise (Chain-wide Executive)',
    jsonb_build_object(
      'unlimited_seats_locations', true,
      'sso', true,
      'audit_logs', true,
      'custom_roles', true,
      'advanced_analytics_exec', true,
      'direct_pos_adaptors', true,
      'loyalty_fleet_mapping', true,
      'custom_feeds', true,
      'priority_sla', true
    ),
    jsonb_build_object(
      'seats', 1000000,
      'locations', 1000000,
      'data_retention_days', 3650
    )
  )
on conflict (price_id) do update set
  plan = excluded.plan,
  name = excluded.name,
  features = excluded.features,
  limits = excluded.limits,
  updated_at = now();

-- Optional: convenience view for Portal UI
create or replace view v_plan_catalog as
select price_id, upper(plan) as plan_code, name, features, limits from plan_catalog;
