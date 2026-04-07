begin;

create table if not exists public.function_rate_limits (
  id uuid primary key default gen_random_uuid(),
  key text not null,
  created_at timestamptz not null default now()
);
create index if not exists idx_function_rate_limits_key_time on public.function_rate_limits (key, created_at desc);

create table if not exists public.metrics_events (
  id uuid primary key default gen_random_uuid(),
  kind text not null,
  props jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_metrics_kind_time on public.metrics_events (kind, created_at desc);

commit;