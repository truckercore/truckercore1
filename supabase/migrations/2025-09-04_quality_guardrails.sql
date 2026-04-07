-- Quality guardrails: idempotency, rate limiting, metrics

-- 1) Server-side idempotency dedupe via partial unique indexes on dispatch_events
--    We assume dispatch_events table exists with columns (event_type text, details jsonb)
create unique index if not exists ux_dispatch_instant_book_key
  on public.dispatch_events ((details->>'key'))
  where event_type = 'instant_book' and (details ? 'key');

create unique index if not exists ux_dispatch_update_status_key
  on public.dispatch_events ((details->>'key'))
  where event_type = 'update_status' and (details ? 'key');

-- 2) Simple function rate limiting storage (append-only)
create table if not exists public.function_rate_limits (
  id uuid primary key default gen_random_uuid(),
  key text not null,
  created_at timestamptz not null default now()
);
create index if not exists idx_function_rate_limits_key_time
  on public.function_rate_limits (key, created_at desc);

-- 3) Minimal metrics/events sink (optional)
create table if not exists public.metrics_events (
  id uuid primary key default gen_random_uuid(),
  kind text not null,
  props jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_metrics_kind_time on public.metrics_events (kind, created_at desc);
