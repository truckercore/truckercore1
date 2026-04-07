-- docs/supabase/speed_tiles_scaffold.sql
-- Safe-to-rerun scaffold for speed tiles aggregation output.

create extension if not exists pgcrypto;

-- Aggregated speeds per WebMercator tile and hour bucket (UTC hour)
create table if not exists public.tiles_speed_agg (
  tile_id text not null,                 -- e.g., "12/1173/1588"
  hour_bucket timestamptz not null,      -- start of the hour (UTC)
  mean_speed numeric(6,2) not null,      -- km/h mean within window
  p95_delay numeric(6,2) not null,       -- rough delta (max - mean) or delay proxy
  samples integer not null default 0,
  updated_at timestamptz not null default now(),
  primary key (tile_id, hour_bucket)
);

create index if not exists idx_tiles_speed_hour on public.tiles_speed_agg(hour_bucket desc);

-- Optional retention guidance (via cron):
-- delete from public.tiles_speed_agg where hour_bucket < now() - interval '90 days';
