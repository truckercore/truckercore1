-- 20250924_market_state_machine.sql
-- Purpose: Loads/Bids state machines with guarded constraints, idempotency keys,
-- race-free matching RPC, API keys + scopes, webhook outbox, fee ledger hygiene,
-- marketplace SLO views, basic rate limiting, and metrics views. Idempotent.

-- ========== 1) Loads/Bids state + constraints ==========
-- Add required columns (safe if already present)
alter table if exists public.loads
  add column if not exists status text not null default 'draft',
  add column if not exists winner_bid_id uuid null,
  add column if not exists posted_at timestamptz,
  add column if not exists matched_at timestamptz;

alter table if exists public.bids
  add column if not exists status text not null default 'open',
  add column if not exists price_cents int not null default 0,
  add column if not exists min_increment_cents int,
  add column if not exists load_id uuid,
  add column if not exists carrier_org_id uuid;

-- Check constraints (guarded since ADD CONSTRAINT doesn't support IF NOT EXISTS)
DO $$
BEGIN
  IF to_regclass('public.loads') IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname='loads_status_chk'
  ) THEN
    ALTER TABLE public.loads
      ADD CONSTRAINT loads_status_chk
      CHECK (status in ('draft','posted','matched','in_transit','delivered','cancelled'));
  END IF;
END$$;

DO $$
BEGIN
  IF to_regclass('public.bids') IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname='bids_status_chk'
  ) THEN
    ALTER TABLE public.bids
      ADD CONSTRAINT bids_status_chk
      CHECK (status in ('open','retracted','accepted','expired','lost'));
  END IF;
END$$;

DO $$
BEGIN
  IF to_regclass('public.bids') IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname='bids_price_chk'
  ) THEN
    ALTER TABLE public.bids
      ADD CONSTRAINT bids_price_chk
      CHECK (price_cents > 0 AND (min_increment_cents IS NULL OR min_increment_cents >= 0));
  END IF;
END$$;

-- A load can be matched only once (winner unique)
CREATE UNIQUE INDEX IF NOT EXISTS loads_winner_uniq
  ON public.loads (winner_bid_id) WHERE winner_bid_id IS NOT NULL;

-- Optional: winner FK -> bids.id (guarded)
DO $$
BEGIN
  IF to_regclass('public.loads') IS NOT NULL AND to_regclass('public.bids') IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='loads_winner_fk') THEN
    ALTER TABLE public.loads
      ADD CONSTRAINT loads_winner_fk
      FOREIGN KEY (winner_bid_id) REFERENCES public.bids(id) ON DELETE SET NULL;
  END IF;
END$$;

-- Transition guard trigger
CREATE OR REPLACE FUNCTION public.enforce_load_transition()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP='UPDATE' THEN
    -- matched: only from posted and must set winner
    IF NEW.status='matched' AND (OLD.status <> 'posted' OR NEW.winner_bid_id IS NULL) THEN
      RAISE EXCEPTION 'invalid transition to matched';
    END IF;
    -- in_transit: only from matched
    IF NEW.status='in_transit' AND OLD.status <> 'matched' THEN
      RAISE EXCEPTION 'invalid transition to in_transit';
    END IF;
    -- delivered: only from in_transit
    IF NEW.status='delivered' AND OLD.status <> 'in_transit' THEN
      RAISE EXCEPTION 'invalid transition to delivered';
    END IF;
    -- posted timestamp set on first transition to posted
    IF NEW.status='posted' AND OLD.status='draft' AND NEW.posted_at IS NULL THEN
      NEW.posted_at := now();
    END IF;
    -- matched timestamp set on transition
    IF NEW.status='matched' AND OLD.status='posted' AND NEW.matched_at IS NULL THEN
      NEW.matched_at := now();
    END IF;
  END IF;
  RETURN NEW;
END$$;

DROP TRIGGER IF EXISTS trg_load_transition ON public.loads;
DO $$
BEGIN
  IF to_regclass('public.loads') IS NOT NULL THEN
    CREATE TRIGGER trg_load_transition
    BEFORE UPDATE ON public.loads
    FOR EACH ROW EXECUTE FUNCTION public.enforce_load_transition();
  END IF;
END$$;

-- ========== 2) Idempotency keys ==========
CREATE TABLE IF NOT EXISTS public.idempotency_keys (
  key text PRIMARY KEY,
  org_id uuid NULL,
  endpoint text NULL,
  request_hash text NULL,
  response jsonb,
  response_code int NULL,
  expires_at timestamptz NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  meta jsonb
);
CREATE INDEX IF NOT EXISTS idempo_exp_idx ON public.idempotency_keys (expires_at);

-- ========== 3) Race-free matching (atomic SKIP LOCKED) ==========
CREATE OR REPLACE FUNCTION public.match_load(p_load_id uuid, p_bid_id uuid, p_requester uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_price int;
  v_carrier uuid;
  v_broker uuid;
BEGIN
  -- lock the load row and ensure it's still posted/available
  PERFORM 1 FROM public.loads
   WHERE id = p_load_id AND status = 'posted'
   FOR UPDATE SKIP LOCKED;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'load unavailable';
  END IF;

  -- lock the winning bid; must be open and for this load
  SELECT price_cents, carrier_org_id INTO v_price, v_carrier
  FROM public.bids
  WHERE id = p_bid_id AND load_id = p_load_id AND status='open'
  FOR UPDATE SKIP LOCKED;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'bid unavailable';
  END IF;

  -- accept winning bid; lose all other open bids on same load
  UPDATE public.bids SET status='accepted' WHERE id = p_bid_id AND status='open';
  UPDATE public.bids SET status='lost' WHERE load_id = p_load_id AND id <> p_bid_id AND status='open';

  -- set winner and transition load -> matched
  UPDATE public.loads
     SET status='matched', winner_bid_id = p_bid_id, matched_at = now()
   WHERE id = p_load_id AND status='posted';

  -- (Optional) resolve broker org for fee ledger
  BEGIN
    SELECT broker_org_id INTO v_broker FROM public.loads WHERE id = p_load_id;
  EXCEPTION WHEN undefined_column THEN
    v_broker := NULL; -- tolerate missing column
  END;

  -- double-entry fee ledger stubs (if table exists)
  IF to_regclass('public.fee_ledger') IS NOT NULL AND v_broker IS NOT NULL THEN
    INSERT INTO public.fee_ledger (ref_type, ref_id, org_id, amount_cents, side, memo)
    VALUES ('bid', p_bid_id, v_carrier,  v_price, 'debit',  'carrier payout'),
           ('bid', p_bid_id, v_broker,   v_price, 'credit', 'load charge');
  END IF;

  RETURN jsonb_build_object('ok', true, 'load_id', p_load_id, 'bid_id', p_bid_id, 'price_cents', v_price);
END$$;

REVOKE ALL ON FUNCTION public.match_load(uuid,uuid,uuid) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.match_load(uuid,uuid,uuid) TO service_role;

-- ========== 4) API keys + scopes ==========
CREATE TABLE IF NOT EXISTS public.api_keys (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL,
  name text NOT NULL,
  hashed_key text NOT NULL,
  scopes text[] NOT NULL,
  created_at timestamptz DEFAULT now(),
  revoked_at timestamptz
);
CREATE INDEX IF NOT EXISTS api_keys_org_idx ON public.api_keys (org_id);

CREATE OR REPLACE FUNCTION public.api_key_has_scope(p_hash text, p_scope text, p_org uuid)
RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.api_keys
     WHERE hashed_key = p_hash
       AND org_id = p_org
       AND revoked_at IS NULL
       AND (p_scope = ANY(scopes) OR 'admin' = ANY(scopes))
  );
$$;

REVOKE ALL ON FUNCTION public.api_key_has_scope(text,text,uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.api_key_has_scope(text,text,uuid) TO authenticated, service_role;

-- ========== 5) Webhook outbox ==========
CREATE TABLE IF NOT EXISTS public.webhook_outbox (
  id bigserial PRIMARY KEY,
  event_type text NOT NULL,
  payload jsonb NOT NULL,
  attempts int NOT NULL DEFAULT 0,
  next_attempt_at timestamptz NOT NULL DEFAULT now(),
  delivered_at timestamptz
);
CREATE INDEX IF NOT EXISTS webhook_outbox_due_idx
  ON public.webhook_outbox (next_attempt_at)
  WHERE delivered_at IS NULL;

-- ========== 6) Fee ledger hygiene (view only if table exists) ==========
DO $$
BEGIN
  IF to_regclass('public.fee_ledger') IS NOT NULL THEN
    EXECUTE $$
      CREATE OR REPLACE VIEW public.v_fee_imbalances AS
      SELECT ref_type, ref_id,
             SUM(CASE WHEN side='debit' THEN amount_cents ELSE -amount_cents END) AS net
      FROM public.fee_ledger
      GROUP BY 1,2
      HAVING SUM(CASE WHEN side='debit' THEN amount_cents ELSE -amount_cents END) <> 0;
    $$;
  END IF;
END$$;

-- ========== 7) Matching SLOs and ops views (guarded) ==========
DO $$
BEGIN
  IF to_regclass('public.loads') IS NOT NULL THEN
    EXECUTE $$
      CREATE OR REPLACE VIEW public.v_match_latency AS
      SELECT id AS load_id,
             EXTRACT(EPOCH FROM (matched_at - posted_at))::int AS seconds_to_match
      FROM public.loads
      WHERE status IN ('matched','in_transit','delivered')
        AND posted_at IS NOT NULL AND matched_at IS NOT NULL;
    $$;

    EXECUTE $$
      CREATE OR REPLACE VIEW public.v_marketplace_health_24h AS
      SELECT
        COUNT(*) FILTER (WHERE l.status='posted'  AND l.posted_at  >= now() - interval '24 hours') AS loads_posted,
        COUNT(*) FILTER (WHERE l.status='matched' AND l.matched_at >= now() - interval '24 hours') AS loads_matched,
        percentile_cont(0.5) WITHIN GROUP (ORDER BY v.seconds_to_match) AS p50_match_s,
        percentile_cont(0.95) WITHIN GROUP (ORDER BY v.seconds_to_match) AS p95_match_s
      FROM public.loads l
      LEFT JOIN public.v_match_latency v ON v.load_id = l.id
      WHERE l.posted_at >= now() - interval '24 hours';
    $$;

    -- Loads status counts
    EXECUTE $$
      CREATE OR REPLACE VIEW public.v_loads_status_counts AS
      SELECT status, count(*) AS cnt
      FROM public.loads
      GROUP BY status;
    $$;

    -- Match conversion
    EXECUTE $$
      CREATE OR REPLACE VIEW public.v_match_conversion_24h AS
      SELECT
        (SELECT count(*) FROM public.loads WHERE posted_at  >= now()-interval '24 hours') AS posted_24h,
        (SELECT count(*) FROM public.loads WHERE matched_at >= now()-interval '24 hours') AS matched_24h;
    $$;
  END IF;
END$$;

-- Bids funnel (guard bids table exists)
DO $$
BEGIN
  IF to_regclass('public.bids') IS NOT NULL THEN
    -- Try to use created_at/updated_at if present; otherwise fallback to status only
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema='public' AND table_name='bids' AND column_name='created_at'
    ) AND EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema='public' AND table_name='bids' AND column_name='updated_at'
    ) THEN
      EXECUTE $$
        CREATE OR REPLACE VIEW public.v_bids_funnel_7d AS
        SELECT
          COUNT(*) FILTER (WHERE status='open'     AND created_at >= now()-interval '7 days') AS bids_opened,
          COUNT(*) FILTER (WHERE status='accepted' AND updated_at >= now()-interval '7 days') AS bids_accepted,
          COUNT(*) FILTER (WHERE status='lost'     AND updated_at >= now()-interval '7 days') AS bids_lost
        FROM public.bids;
      $$;
    ELSE
      EXECUTE $$
        CREATE OR REPLACE VIEW public.v_bids_funnel_7d AS
        SELECT
          COUNT(*) FILTER (WHERE status='open')     AS bids_opened,
          COUNT(*) FILTER (WHERE status='accepted') AS bids_accepted,
          COUNT(*) FILTER (WHERE status='lost')     AS bids_lost
        FROM public.bids;
      $$;
    END IF;
  END IF;
END$$;

-- ========== 8) Rate limiting (per API key, sliding minute) ==========
CREATE TABLE IF NOT EXISTS public.api_rate (
  key_hash text NOT NULL,
  bucket text NOT NULL,
  at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (key_hash, bucket, at)
);

CREATE OR REPLACE FUNCTION public.api_rate_check(p_hash text, p_bucket text, p_limit int)
RETURNS boolean LANGUAGE sql STABLE AS $$
  WITH ins AS (
    INSERT INTO public.api_rate(key_hash,bucket,at)
    VALUES (p_hash,p_bucket,date_trunc('minute', now()))
    ON CONFLICT DO NOTHING
    RETURNING 1
  )
  SELECT (
    SELECT count(*) FROM public.api_rate
     WHERE key_hash=p_hash AND bucket=p_bucket
       AND at >= now() - interval '1 minute'
  ) <= p_limit;
$$;

REVOKE ALL ON FUNCTION public.api_rate_check(text,text,int) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.api_rate_check(text,text,int) TO service_role, authenticated;

-- Notes: RLS enforcement for loads/bids should be configured in separate policies.
-- Retention: schedule a daily job to delete idempotency_keys where expires_at < now().
