-- docs/security/role_worker_outbox.sql
-- Least-privilege role for webhook/outbox worker
-- Adjust schema/table names to your environment.

-- 1) Create role (use a strong password from secrets manager)
-- CREATE ROLE worker_outbox LOGIN PASSWORD 'REDACTED_SECRET_PASSWORD';

-- 2) Revoke broad defaults
REVOKE ALL ON SCHEMA public FROM worker_outbox;
GRANT USAGE ON SCHEMA public TO worker_outbox;

-- 3) Grant only required table privileges
GRANT SELECT ON public.webhook_subscriptions TO worker_outbox;
GRANT SELECT, UPDATE ON public.event_outbox TO worker_outbox;
GRANT INSERT ON public.webhook_deliveries TO worker_outbox;

-- Optional helper: limited function executes
-- GRANT EXECUTE ON FUNCTION public.outbox_claim_pending(integer) TO worker_outbox;

-- 4) Ensure RLS policies allow worker_outbox as needed (or disable RLS on these tables)
-- Example: ALTER TABLE public.event_outbox ENABLE ROW LEVEL SECURITY; (if enabled)
-- CREATE POLICY worker_outbox_update ON public.event_outbox FOR UPDATE
--   TO worker_outbox USING (true) WITH CHECK (true);

-- 5) Configure the worker connection string to use worker_outbox role.
-- e.g., postgres://worker_outbox:***@db:5432/appdb
