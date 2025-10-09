-- 20250924_ingest_log.sql
-- Observability: ingest_log table and index (idempotent)

create table if not exists public.ingest_log (
  id uuid primary key default gen_random_uuid(),
  source text not null,
  rows_ingested int not null default 0,
  duration_ms int not null default 0,
  ok boolean not null default true,
  ran_at timestamptz not null default now(),
  meta jsonb not null default '{}'::jsonb
);

create index if not exists idx_ingest_log_source_time on public.ingest_log (source, ran_at desc);
