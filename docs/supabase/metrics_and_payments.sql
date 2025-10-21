-- docs/supabase/metrics_and_payments.sql
-- Updated_at triggers on selected tables and payments audit indexes/constraints.
-- Idempotent; safe to re-run.

create extension if not exists pgcrypto;

-- Touch function
create or replace function public.tg_touch_updated_at() returns trigger
language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

-- Attach triggers if columns exist
DO $$ BEGIN
  IF EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='promotions' AND column_name='updated_at') THEN
    EXECUTE 'DROP TRIGGER IF EXISTS trg_promotions_touch ON public.promotions';
    EXECUTE 'CREATE TRIGGER trg_promotions_touch BEFORE UPDATE ON public.promotions FOR EACH ROW EXECUTE FUNCTION public.tg_touch_updated_at()';
  END IF;
  IF EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='pois' AND column_name='updated_at') THEN
    EXECUTE 'DROP TRIGGER IF EXISTS trg_pois_touch ON public.pois';
    EXECUTE 'CREATE TRIGGER trg_pois_touch BEFORE UPDATE ON public.pois FOR EACH ROW EXECUTE FUNCTION public.tg_touch_updated_at()';
  END IF;
  IF EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='payments' AND column_name='updated_at') THEN
    EXECUTE 'DROP TRIGGER IF EXISTS trg_payments_touch ON public.payments';
    EXECUTE 'CREATE TRIGGER trg_payments_touch BEFORE UPDATE ON public.payments FOR EACH ROW EXECUTE FUNCTION public.tg_touch_updated_at()';
  END IF;
END $$;

-- Payments idempotency key and indexes
DO $$ BEGIN
  IF EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='payments') THEN
    -- Add idempotency_key column if missing
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='payments' AND column_name='idempotency_key'
    ) THEN
      EXECUTE 'ALTER TABLE public.payments ADD COLUMN idempotency_key text';
    END IF;
    -- Unique on idempotency_key
    BEGIN
      EXECUTE 'ALTER TABLE public.payments ADD CONSTRAINT payments_idempotency_key_uniq UNIQUE (idempotency_key)';
    EXCEPTION WHEN duplicate_object THEN
      -- already present
      NULL;
    END;
    -- Org/time index
    BEGIN
      EXECUTE 'CREATE INDEX IF NOT EXISTS idx_payments_org_created ON public.payments (org_id, created_at DESC)';
    EXCEPTION WHEN undefined_table THEN NULL; END;
  END IF;
END $$;
