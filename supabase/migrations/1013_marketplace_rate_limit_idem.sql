-- 1013_marketplace_rate_limit_idem.sql
-- Add idempotency keys and simple rate limit guard for marketplace offers/bids.

-- 1) Idempotency key column + unique index (safe if table exists)
DO $$ BEGIN
  IF to_regclass('public.marketplace_offers') IS NOT NULL THEN
    -- Column is nullable; clients set it when they want duplicate suppression
    BEGIN
      ALTER TABLE public.marketplace_offers ADD COLUMN IF NOT EXISTS idempotency_key text;
    EXCEPTION WHEN duplicate_column THEN NULL; END;
    CREATE UNIQUE INDEX IF NOT EXISTS ux_mkt_offers_idem
      ON public.marketplace_offers(idempotency_key)
      WHERE idempotency_key IS NOT NULL;
  END IF;
END $$;

-- 2) Rate limit helper for bids (uses existing rate_limit_* helpers)
create or replace function public.rate_limit_guard_bid(actor uuid, max_calls int default 10, window_secs int default 60)
returns void
language plpgsql
security definer
set search_path=public
as $$
begin
  if not public.rate_limited(actor, 'place_bid', max_calls, window_secs) then
    raise exception 'rate limit exceeded' using errcode = 'P0001';
  end if;
  perform public.rate_limit_touch(actor, 'place_bid');
end;
$$;

-- 3) (Optional) Trigger to populate idempotency_key if missing (hash of bidder+load+amount+message)
DO $$ BEGIN
  IF to_regclass('public.marketplace_offers') IS NOT NULL THEN
    CREATE OR REPLACE FUNCTION public._mkt_offers_default_idem()
    RETURNS trigger LANGUAGE plpgsql AS $$
    DECLARE
      basis text;
    BEGIN
      IF NEW.idempotency_key IS NULL THEN
        basis := coalesce(NEW.bidder_user_id::text,'')||'|'||coalesce(NEW.load_id::text,'')||'|'||coalesce(NEW.bid_cents::text,'')||'|'||coalesce(NEW.message,'');
        NEW.idempotency_key := encode(digest(basis, 'sha256'),'hex');
      END IF;
      RETURN NEW;
    END $$;

    -- Attach trigger (if not exists)
    BEGIN
      CREATE TRIGGER trg_mkt_offers_default_idem BEFORE INSERT ON public.marketplace_offers
      FOR EACH ROW EXECUTE PROCEDURE public._mkt_offers_default_idem();
    EXCEPTION WHEN duplicate_object THEN NULL; END;
  END IF;
END $$;