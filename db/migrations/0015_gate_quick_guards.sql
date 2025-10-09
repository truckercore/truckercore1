-- 0015_gate_quick_guards.sql
-- Purpose: Quick idempotent guards to support gate runner
-- - Unique indexes on dispatch_events detail keys for selected event types
-- - Function rate limit store table + index
-- - Minimal metrics sink table + index
-- All statements are idempotent and safe to re-run.

begin;

-- Idempotent dispatch event unique keys (only when details contains 'key')
create unique index if not exists ux_dispatch_instant_book_key
  on public.dispatch_events ((details->>'key'))
  where event_type = 'instant_book' and (details ? 'key');

create unique index if not exists ux_dispatch_update_status_key
  on public.dispatch_events ((details->>'key'))
  where event_type = 'update_status' and (details ? 'key');

-- Function rate limit store
create table if not exists public.function_rate_limits (
  id uuid primary key default gen_random_uuid(),
  key text not null,
  created_at timestamptz not null default now()
);
create index if not exists idx_function_rate_limits_key_time
  on public.function_rate_limits (key, created_at desc);

-- Minimal metrics sink
create table if not exists public.metrics_events (
  id uuid primary key default gen_random_uuid(),
  kind text not null,
  props jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_metrics_kind_time on public.metrics_events (kind, created_at desc);

commit;