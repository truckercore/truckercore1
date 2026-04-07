-- Consistency, RLS strictness, and policy audit helpers (2025-09)
-- Run these read-only queries to surface common problems.

-- 1) Canonical load statuses (should match: draft, assigned, in_transit, delivered, canceled)
SELECT status, COUNT(*) AS n
FROM public.loads
GROUP BY 1
ORDER BY 2 DESC;

-- 2) Non-canonical statuses (lint)
SELECT status, COUNT(*) AS n
FROM public.loads
WHERE status NOT IN ('draft','assigned','in_transit','delivered','canceled')
GROUP BY 1
ORDER BY 2 DESC;

-- 3) Check that broker_id exists on loads
SELECT column_name
FROM information_schema.columns
WHERE table_schema='public' AND table_name='loads' AND column_name='broker_id';

-- 4) Legacy brokerage_id artifacts: tables, views, indexes
SELECT table_schema, table_name, column_name
FROM information_schema.columns
WHERE column_name = 'brokerage_id'
ORDER BY table_schema, table_name;

SELECT schemaname, indexname, indexdef
FROM pg_indexes
WHERE indexdef ILIKE '%brokerage_id%';

-- 5) RLS policy review: look for risky ORs that may bypass tenant checks.
-- Manually inspect any policy whose qual/with_check contains ' OR ' (case-insensitive).
SELECT policyname, tablename, qual, with_check
FROM pg_policies
WHERE (qual ILIKE '% OR %' OR with_check ILIKE '% OR %')
ORDER BY tablename, policyname;

-- 6) Confirm RLS is enabled for sensitive tables
SELECT relname AS table, relrowsecurity AS rls_on
FROM pg_class
WHERE relname IN ('loads','trips','documents','owner_ops','owner_op_trips','trip_expenses','owner_op_invoices')
ORDER BY relname;

-- 7) Indexes used by hot queries
-- Validate presence of (broker_id, status) index
SELECT indexname, indexdef FROM pg_indexes WHERE tablename='loads' AND indexdef ILIKE '%(broker_id, status)%';

-- 8) Views referencing status: ensure they don’t cast/alias legacy columns
SELECT viewname, definition
FROM pg_views
WHERE definition ILIKE '% loads.%status%';

-- 9) Explain example (replace UUID)
-- EXPLAIN ANALYZE SELECT * FROM public.loads WHERE broker_id = '00000000-0000-0000-0000-000000000000' AND status = 'draft' LIMIT 10;
