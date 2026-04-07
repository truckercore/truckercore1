-- Server-driven feature catalog for upsell (idempotent)
create table if not exists public.feature_catalog (
  key text primary key,
  tier text not null check (tier in ('premium','ai')),
  headline text not null,
  blurb text,
  runbook_url text,
  price_id text not null,
  variant text,
  locale text,
  updated_at timestamptz not null default now()
);

-- Simple seed examples (safe to re-run)
insert into public.feature_catalog(key, tier, headline, blurb, runbook_url, price_id, variant, locale)
values
  ('fleet.ai_capacity', 'ai', 'AI Capacity Forecasting', 'Predict imbalances by lane and assign loads proactively.', 'https://example.com/runbooks/ai_capacity', 'price_ai_example', 'A', 'en'),
  ('fleet.analytics', 'premium', 'Premium Fleet Analytics', 'Deeper insights and custom dashboards.', 'https://example.com/runbooks/premium_analytics', 'price_premium_example', 'A', 'en')
on conflict (key) do nothing;
