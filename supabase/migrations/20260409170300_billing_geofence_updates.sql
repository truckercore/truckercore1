-- ============================================================
-- MIGRATION: Billing limits and Geofence metadata
-- ============================================================

-- MIGRATION 1: Billing limits on profiles
alter table profiles
  add column if not exists plan_limits  jsonb default '{
    "max_trucks": 5,
    "max_drivers": 10,
    "max_routes_per_day": 50
  }'::jsonb,
  add column if not exists usage_stats  jsonb default '{
    "active_trucks": 0,
    "drivers": 0,
    "routes_today": 0
  }'::jsonb;

-- Hard enforcement: block truck add when at limit
-- Note: Assuming drivers table is used for both trucks and drivers in this context 
-- or that the user intended to reference a vehicles table for trucks.
-- Based on the provided issue description, it uses 'drivers' table for both check policies.

create policy "enforce_truck_limit"
  on drivers
  for insert
  with check (
    (
      select (usage_stats->>'active_trucks')::int
      from profiles
      where id = auth.uid()
    )
    <
    (
      select (plan_limits->>'max_trucks')::int
      from profiles
      where id = auth.uid()
    )
  );

-- Hard enforcement: block driver add when at limit
create policy "enforce_driver_limit"
  on drivers
  for insert
  with check (
    (
      select (usage_stats->>'drivers')::int
      from profiles
      where id = auth.uid()
    )
    <
    (
      select (plan_limits->>'max_drivers')::int
      from profiles
      where id = auth.uid()
    )
  );


-- MIGRATION 2: Geofence events — severity + dispatcher fields
alter table geofence_events
  add column if not exists severity      text    default 'info'
    check (severity in ('critical', 'warning', 'info')),
  add column if not exists eta_delay     int,        -- minutes
  add column if not exists acknowledged  boolean default false,
  add column if not exists driver_name   text,
  add column if not exists zone_name     text;

-- Index for fast live-feed queries
create index if not exists idx_geofence_events_org_acked
  on geofence_events (org_id, acknowledged, created_at desc);
