-- 20250924_incidents_weather.sql
-- DOT 511 / NOAA ingest schema: road_closures, weather_hazards, supporting extensions
-- Idempotent.

-- Optional: simple geo bbox RPC (earthdistance)
create extension if not exists cube;
create extension if not exists earthdistance;

-- Closures/incidents (DOT 511)
create table if not exists public.road_closures (
  id uuid primary key default gen_random_uuid(),
  source text not null,                      -- e.g., 'wa_511'
  ext_id text not null,                      -- source unique id
  state text not null,
  geometry jsonb not null,                   -- store as JSON (GeoJSON)
  start_time timestamptz,
  end_time timestamptz,
  lanes text null,                           -- e.g., "EB right 2 lanes"
  severity text null,                        -- minor|moderate|major|unknown
  cause text null,                           -- crash|construction|weather|...
  last_seen timestamptz not null default now(),
  expires_at timestamptz not null,
  meta jsonb not null default '{}'::jsonb,
  unique (source, ext_id)
);
create index if not exists idx_closures_expires on public.road_closures (expires_at);
create index if not exists idx_closures_state on public.road_closures (state);

-- NOAA / NWS hazards
create table if not exists public.weather_hazards (
  id uuid primary key default gen_random_uuid(),
  source text not null default 'nws',
  ext_id text not null,                      -- NWS id
  kind text not null,                        -- e.g., "Winter Storm Warning"
  severity text null,                        -- minor|moderate|severe|extreme
  area text[] null,
  geometry jsonb not null,
  onset timestamptz,
  expires_at timestamptz not null,
  last_seen timestamptz not null default now(),
  meta jsonb not null default '{}'::jsonb,
  unique (source, ext_id)
);
create index if not exists idx_hazards_expires on public.weather_hazards (expires_at);
