-- docs/supabase/roadside_indexes.sql
-- Minimal helper indexes for roadside domain tables. Idempotent and safe to re-run.

-- Ensure the underlying roadside tables exist per your schema before running these indexes.
-- These indexes improve common query patterns used by matching, assignments, and status updates.

-- Locations: lookup by provider and simple lat/lng filters
CREATE INDEX IF NOT EXISTS idx_rs_locations_provider ON public.roadside_locations(provider_id);
-- Note: for true geo queries, consider PostGIS. This simple composite can still help range scans on lat/lng.
CREATE INDEX IF NOT EXISTS idx_rs_locations_latlng ON public.roadside_locations(lat, lng);

-- Services: join by provider
CREATE INDEX IF NOT EXISTS idx_rs_services_provider ON public.roadside_services(provider_id);

-- Requests: filter by status and recency
CREATE INDEX IF NOT EXISTS idx_rs_requests_status_created ON public.roadside_requests(status, created_at DESC);

-- Jobs: list recent jobs per provider
CREATE INDEX IF NOT EXISTS idx_rs_jobs_provider_time ON public.roadside_jobs(provider_id, accepted_at DESC);
