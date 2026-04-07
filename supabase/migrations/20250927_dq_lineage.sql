-- Migration: Data lineage and market rates structures
-- Date: 2025-09-27

-- Lineage & audits
create table if not exists public.ingest_job_runs (
  id bigserial primary key,
  job_name text not null,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  status text not null default 'running',
  error text
);

create table if not exists public.source_files (
  id bigserial primary key,
  job_run_id bigint references public.ingest_job_runs(id),
  source text not null,
  version text,
  collected_at timestamptz not null,
  uri text,
  row_count int,
  checksum text
);

create table if not exists public.row_counts (
  day date primary key,
  table_name text not null,
  count bigint not null
);

-- Market rates with dedupe & freshness controls
create table if not exists public.market_rates (
  lane_key text not null,
  day date not null,
  source text not null,
  price numeric not null,
  confidence numeric not null default 0.5,
  collected_at timestamptz not null,
  unique (lane_key, day, source)
);

-- Best-source-wins materialized view
create materialized view if not exists public.market_rates_best as
select distinct on (lane_key, day)
  lane_key, day, source, price, confidence, collected_at
from public.market_rates
order by lane_key, day, confidence desc, collected_at desc;

create index if not exists idx_market_rates_best_day on public.market_rates_best (day);
