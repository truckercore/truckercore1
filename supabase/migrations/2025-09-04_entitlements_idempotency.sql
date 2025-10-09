-- Ensure processed_events table for webhook idempotency and metrics logging
create table if not exists public.processed_events (
  id text primary key,
  kind text not null,
  created_at timestamptz not null default now()
);

-- Helpful index for querying by kind/time
create index if not exists idx_processed_events_kind_time on public.processed_events (kind, created_at desc);
