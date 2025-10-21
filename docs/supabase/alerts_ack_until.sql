-- docs/supabase/alerts_ack_until.sql
-- Adds acknowledged_until column to alerts_events for suppression and shows example suppression query.
-- Idempotent and safe to re-run.

ALTER TABLE IF EXISTS public.alerts_events
  ADD COLUMN IF NOT EXISTS acknowledged_until timestamptz null;

-- RLS remains as defined in alerts_reporting.sql (org-scoped SELECT). Updates allowed per existing policies.
-- Suppression check example (use in notifier queries):
--   where (acknowledged_until is null OR acknowledged_until < now())
