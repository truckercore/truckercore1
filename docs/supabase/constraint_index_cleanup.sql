-- Constraint and Index Cleanup Script
-- Purpose: Remove a legacy unique constraint on dispatch_order_legs and a duplicate index on pings, if they exist.
-- Safety: Idempotent; guarded by existence checks. Safe to run multiple times.
-- Usage: Execute after base schema migrations via psql or Supabase SQL editor.

-- 1) Drop legacy unique constraint on public.dispatch_order_legs if it exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint c JOIN pg_class t ON c.conrelid = t.oid
    WHERE t.relname='dispatch_order_legs' AND c.conname='dispatch_order_legs_order_id_seq_key'
  ) THEN
    EXECUTE 'ALTER TABLE public.dispatch_order_legs DROP CONSTRAINT IF EXISTS dispatch_order_legs_order_id_seq_key';
  END IF;
END $$;

-- 2) Drop duplicate index on public.pings if table exists (replace index name if needed)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='pings'
  ) THEN
    -- Replace 'pings_duplicate_idx' with the real index name if a duplicate exists
    EXECUTE 'DROP INDEX IF EXISTS pings_duplicate_idx';
  END IF;
END $$;