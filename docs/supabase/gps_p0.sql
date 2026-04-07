-- docs/supabase/gps_p0.sql
-- P0 schema for GPS ingestion hardening: unique keys, indexes, retention, and metrics hints

-- Table: tracking_points
-- Stores raw GPS points uploaded by driver devices.
-- Use a natural device identifier (uuid string) + monotonically increasing seq per device for idempotency/ordering.

create table if not exists public.tracking_points (
  device_id text not null,
  org_id text, -- optional: set if available to support org-level queries & indexes
  seq bigint not null,
  ts timestamptz not null,
  lat double precision not null,
  lng double precision not null,
  speed_mps double precision,
  activity text, -- driving|idle|unknown (client hint)
  battery_pct smallint, -- 0..100 (optional)
  raw jsonb, -- optional extended payload (accuracy, altitude, heading)
  inserted_at timestamptz not null default now()
);

-- Composite indexes for hot paths (DESC on ts for newest-first scans)
create index if not exists tracking_points_device_ts_desc_idx
  on public.tracking_points (device_id, ts desc);
create index if not exists tracking_points_org_ts_desc_idx
  on public.tracking_points (org_id, ts desc);

-- Idempotency + ordering keys
create unique index if not exists tracking_points_device_seq_ux
  on public.tracking_points (device_id, seq);
create index if not exists tracking_points_device_ts_idx
  on public.tracking_points (device_id, ts);

-- Optional unique key if clients provide an explicit unique key (e.g., hash)
-- alter table public.tracking_points add column if not exists uniq_key text;
-- create unique index if not exists tracking_points_uniq_key_ux on public.tracking_points(uniq_key);

-- Basic RLS (example – adjust to your auth model)
-- alter table public.tracking_points enable row level security;
-- create policy if not exists tracking_points_insert
--   on public.tracking_points for insert
--   with check (true);
-- create policy if not exists tracking_points_select
--   on public.tracking_points for select
--   using (true);

-- Retention: keep 90 days online; older data can be moved to cold storage.
-- Example daily job:
-- delete from public.tracking_points where ts < now() - interval '90 days';

-- Optional monthly partitioning (Postgres native partitioning)
-- create table if not exists public.tracking_points_y2025m09 partition of public.tracking_points
--   for values from ('2025-09-01') to ('2025-10-01');
-- Consider creating partitions per month and attaching appropriate indexes.

-- Ingest metrics (Prometheus friendly) are produced by the Node/Express ingest stub in scripts/server/ingest_tracking.mjs.
