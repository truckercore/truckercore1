-- Webhook idempotency (no double-grants on retries)
create table if not exists public.stripe_events_dedup (
  id text primary key,              -- Stripe event id (evt_*)
  type text not null,
  received_at timestamptz not null default now()
);
