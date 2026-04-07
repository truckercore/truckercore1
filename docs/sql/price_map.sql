-- Price→Entitlement mapping (single source of truth)
create table if not exists public.stripe_price_map (
  price_id text primary key,              -- price_*
  tier text not null check (tier in ('basic','premium','ai')),
  ai_enabled boolean not null default false
);

-- Example rows (safe to re-run)
insert into public.stripe_price_map (price_id, tier, ai_enabled)
values
  ('price_ai_123', 'ai', true),
  ('price_prem_456', 'premium', false)
on conflict do nothing;
