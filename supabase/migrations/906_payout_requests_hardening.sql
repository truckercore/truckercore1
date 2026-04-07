-- 906_payout_requests_hardening.sql
-- Guardrails / bookkeeping columns for instant pay

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='payout_requests' AND column_name='reviewed_by'
  ) THEN
    ALTER TABLE public.payout_requests ADD COLUMN reviewed_by uuid;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='payout_requests' AND column_name='reviewed_at'
  ) THEN
    ALTER TABLE public.payout_requests ADD COLUMN reviewed_at timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='payout_requests' AND column_name='decision_notes'
  ) THEN
    ALTER TABLE public.payout_requests ADD COLUMN decision_notes text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='payout_requests' AND column_name='fee_usd'
  ) THEN
    ALTER TABLE public.payout_requests ADD COLUMN fee_usd numeric(12,2) DEFAULT 0;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='payout_requests' AND column_name='net_amount_usd'
  ) THEN
    ALTER TABLE public.payout_requests ADD COLUMN net_amount_usd numeric(12,2) GENERATED ALWAYS AS (amount_usd - COALESCE(fee_usd,0)) STORED;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='payout_requests' AND column_name='stripe_transfer_id'
  ) THEN
    ALTER TABLE public.payout_requests ADD COLUMN stripe_transfer_id text;
  END IF;
END$$;
