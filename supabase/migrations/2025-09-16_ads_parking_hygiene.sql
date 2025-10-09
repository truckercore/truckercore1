-- 2025-09-16_ads_parking_hygiene.sql
-- Enable geospatial helpers and add helpful indexes for ads and parking status per implementation notes.

begin;

-- Enable cube/earthdistance for ll_to_earth/earth_distance usage (safe if already enabled)
create extension if not exists cube;
create extension if not exists earthdistance;

-- Unique index to support upsert on parking_status(stop_id)
create unique index if not exists ux_parking_status_stop on public.parking_status(stop_id);

-- Partial index to speed up "active now" ads scans
create index if not exists idx_ads_active_now on public.ads(active_from, active_to)
where now() between active_from and active_to;

commit;
