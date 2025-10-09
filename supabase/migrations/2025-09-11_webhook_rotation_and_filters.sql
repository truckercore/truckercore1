-- Webhook rotation and per-topic filters + concurrency caps
alter table if exists public.webhook_subscriptions
  add column if not exists secret_next text,
  add column if not exists secret_next_expires_at timestamptz,
  add column if not exists topic_filters text[],
  add column if not exists max_in_flight int;

-- Backfill: ensure endpoint_url is set from url if exists
update public.webhook_subscriptions set endpoint_url = coalesce(endpoint_url, url) where true;

-- Helpful index
create index if not exists idx_webhook_subs_org_active on public.webhook_subscriptions (org_id) where coalesce(is_active, active, true) = true;
