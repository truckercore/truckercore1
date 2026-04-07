-- 20250924_gps_samples.sql
-- GPS/telemetry ingestion table. Idempotent.

create table if not exists public.gps_samples (
  id bigserial primary key,
  lat double precision not null,
  lng double precision not null,
  speed_kph double precision not null default 0,
  heading_deg int not null default 0,
  accuracy_m int not null default 50,
  source text not null default 'mobile',
  ts timestamptz not null default now(),
  meta jsonb not null default '{}'::jsonb
);

create index if not exists idx_gps_ts on public.gps_samples (ts desc);
create index if not exists idx_gps_source_ts on public.gps_samples (source, ts desc);
