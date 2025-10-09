-- 200_licensing_core.sql
-- Enrich orgs with licensing columns
alter table if exists public.orgs
  add column if not exists plan text not null default 'free',
  add column if not exists license_status text not null default 'inactive',
  add column if not exists app_is_premium boolean not null default false;

-- License snapshots & history
create table if not exists public.org_license_events (
  id bigint generated always as identity primary key,
  org_id uuid not null references public.orgs(id) on delete cascade,
  source text not null,
  action text not null,
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_org_license_events_org_ts on public.org_license_events(org_id, created_at desc);

-- Webhook retry queue
create table if not exists public.webhook_retry (
  id uuid primary key default gen_random_uuid(),
  provider text not null,
  event_id text not null,
  attempt integer not null default 0,
  max_attempts integer not null default 6,
  next_run_at timestamptz not null default now(),
  status text not null default 'queued',
  last_error text
);
create index if not exists idx_webhook_retry_due on public.webhook_retry(next_run_at, status);

-- Lightweight locks
create table if not exists public.process_locks (
  key text primary key,
  holder text not null,
  acquired_at timestamptz not null default now(),
  ttl_seconds integer not null default 120
);

-- CSV import usage (per org)
create table if not exists public.csv_ingest_usage (
  id bigint generated always as identity primary key,
  org_id uuid not null references public.orgs(id) on delete cascade,
  bytes bigint not null,
  files integer not null default 1,
  occurred_at timestamptz not null default now()
);
create index if not exists idx_csv_usage_window on public.csv_ingest_usage(org_id, occurred_at desc);

-- Optional helper RPC for 24h usage sum
create or replace function public.sum_csv_usage_24h(p_org uuid)
returns bigint
language sql
stable
as $$
  select coalesce(sum(bytes),0)::bigint
  from public.csv_ingest_usage
  where org_id = p_org
    and occurred_at >= now() - interval '24 hours'
$$;