-- Zero-downtime column/type change template (add_v2 → repoint views → swap)
-- Use this pattern when changing a column type or semantics referenced by views/materialized views.
-- Example: loads.status TEXT → constrained TEXT with new semantics, or enum introduction later.

BEGIN;

-- 1) Add new column _v2 with target type/constraint (keep original intact)
ALTER TABLE public.loads ADD COLUMN IF NOT EXISTS status_v2 TEXT;
-- Add CHECK for canonical values on the new column
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.constraint_column_usage c
    WHERE c.table_name = 'loads' AND c.column_name = 'status_v2' AND c.constraint_name = 'loads_status_v2_check')
  THEN
    EXECUTE $$ALTER TABLE public.loads
      ADD CONSTRAINT loads_status_v2_check
      CHECK (status_v2 IN ('draft','assigned','in_transit','delivered','canceled'))$$;
  END IF;
END$$;

-- 2) Backfill v2 from old column (idempotent)
UPDATE public.loads
SET status_v2 = CASE status
  WHEN 'open' THEN 'draft'              -- example mapping
  WHEN 'pending' THEN 'draft'
  ELSE status
END
WHERE status_v2 IS DISTINCT FROM (
  CASE status WHEN 'open' THEN 'draft' WHEN 'pending' THEN 'draft' ELSE status END
);

-- 3) Repoint dependent views to use status_v2
-- Replace <your_view_name> with real views; update definitions accordingly.
-- Example:
-- CREATE OR REPLACE VIEW public.loads_active_v AS
-- SELECT id, broker_id, status_v2 AS status, pickup_location, dropoff_location
-- FROM public.loads
-- WHERE status_v2 IN ('assigned','in_transit');

-- 4) Swap: once views and code are migrated, move v2 into place
-- a) Drop old CHECK/defaults on legacy column (if any)
ALTER TABLE public.loads DROP CONSTRAINT IF EXISTS loads_status_check;
ALTER TABLE public.loads ALTER COLUMN status DROP DEFAULT;

-- b) Rename columns to swap
-- Note: wrap in DO block if you need to guard on existence.
ALTER TABLE public.loads RENAME COLUMN status TO status_legacy;
ALTER TABLE public.loads RENAME COLUMN status_v2 TO status;

-- c) Recreate constraint/default on new status column
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.constraint_column_usage c
    WHERE c.table_name = 'loads' AND c.column_name = 'status' AND c.constraint_name = 'loads_status_check')
  THEN
    EXECUTE $$ALTER TABLE public.loads
      ADD CONSTRAINT loads_status_check
      CHECK (status IN ('draft','assigned','in_transit','delivered','canceled'))$$;
  END IF;
END$$;
ALTER TABLE public.loads ALTER COLUMN status SET DEFAULT 'draft';

-- 5) Optional: drop legacy column after validation window
-- ALTER TABLE public.loads DROP COLUMN IF EXISTS status_legacy;

COMMIT;

-- Verification:
-- SELECT DISTINCT status FROM public.loads ORDER BY 1;
-- Ensure all views/materialized views reference the new column.
