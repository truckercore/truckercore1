-- Referrals auto-reward pipeline: idempotent RPC + attribution + daily sweep
-- Safe to run multiple times

-- 1) Attribution columns on referral_events
ALTER TABLE IF EXISTS public.referral_events
  ADD COLUMN IF NOT EXISTS ref_source text,
  ADD COLUMN IF NOT EXISTS campaign text,
  ADD COLUMN IF NOT EXISTS medium text,
  ADD COLUMN IF NOT EXISTS landing_page text,
  ADD COLUMN IF NOT EXISTS user_agent text;

-- 2) Rewards table with self-referral check and idempotency
CREATE TABLE IF NOT EXISTS public.referral_rewards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  inviter_user_id uuid NOT NULL,
  referred_user_id uuid NOT NULL,
  org_id uuid,
  code text,
  reward_type text NOT NULL DEFAULT 'credit', -- credit | free_month | etc
  amount_cents integer NOT NULL DEFAULT 2500, -- default $25
  redeemed boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Idempotency: one reward per (inviter, referred)
CREATE UNIQUE INDEX IF NOT EXISTS uq_referral_rewards_pair ON public.referral_rewards(inviter_user_id, referred_user_id);

-- Quick self-referral block
ALTER TABLE IF EXISTS public.referral_rewards
  ADD CONSTRAINT chk_no_self_referral CHECK (inviter_user_id IS NULL OR referred_user_id IS NULL OR inviter_user_id <> referred_user_id);

-- 3) Lifetime cap helper (simple default: 20 lifetime rewards; adapt later to read from settings)
CREATE OR REPLACE FUNCTION public.can_issue_more_rewards(p_inviter uuid)
RETURNS boolean
LANGUAGE sql STABLE
AS $$
  SELECT COALESCE((SELECT count(*) FROM public.referral_rewards r WHERE r.inviter_user_id = p_inviter),0) < 20;
$$;

-- 4) Core RPC: issue_referral_reward_once(booker_user_id, org_id)
-- Logic:
--  - Find latest referral event for this referred user (signed_up/booked) and its code/issuer
--  - Block self-referrals
--  - Check lifetime cap via can_issue_more_rewards
--  - Idempotent insert into referral_rewards (unique on inviter/referred)
--  - Credit ledger insert for inviter (reason: referral_booking), if reward newly created
-- Returns: JSON with status and details
CREATE OR REPLACE FUNCTION public.issue_referral_reward_once(p_booker_user_id uuid, p_org_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_code text;
  v_inviter uuid;
  v_created boolean := false;
  v_reward_id uuid;
  v_amount integer := 2500; -- default cents
BEGIN
  IF p_booker_user_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'missing_booker');
  END IF;

  -- Find latest referral event and map to inviter via referral_codes
  SELECT e.code, c.issuer_user_id
    INTO v_code, v_inviter
  FROM public.referral_events e
  JOIN public.referral_codes c ON c.code = e.code
  WHERE e.referred_user_id = p_booker_user_id
    AND e.status IN ('signed_up','booked')
  ORDER BY e.created_at DESC
  LIMIT 1;

  IF v_code IS NULL OR v_inviter IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'no_referral_found');
  END IF;

  -- Self referral guard (also enforced by table check)
  IF v_inviter = p_booker_user_id THEN
    RETURN jsonb_build_object('ok', false, 'error', 'self_referral_blocked');
  END IF;

  -- Lifetime cap
  IF NOT public.can_issue_more_rewards(v_inviter) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'lifetime_cap_reached');
  END IF;

  -- Idempotent insert
  INSERT INTO public.referral_rewards (inviter_user_id, referred_user_id, org_id, code, reward_type, amount_cents)
  VALUES (v_inviter, p_booker_user_id, p_org_id, v_code, 'credit', v_amount)
  ON CONFLICT ON CONSTRAINT uq_referral_rewards_pair DO NOTHING;

  GET DIAGNOSTICS v_created = ROW_COUNT > 0;

  -- Fetch reward id (exists either way)
  SELECT id INTO v_reward_id
  FROM public.referral_rewards
  WHERE inviter_user_id = v_inviter AND referred_user_id = p_booker_user_id;

  -- Post credit only if we created a new reward now
  IF v_created THEN
    INSERT INTO public.credit_ledger (user_id, amount_cents, reason, meta)
    VALUES (v_inviter, v_amount, 'referral_booking', jsonb_build_object('code', v_code, 'referred_user_id', p_booker_user_id, 'reward_id', v_reward_id));
  END IF;

  RETURN jsonb_build_object('ok', true, 'created', v_created, 'reward_id', v_reward_id, 'inviter_user_id', v_inviter, 'amount_cents', v_amount);
END;
$$;

-- 5) Daily sweep: process booked users without rewards
CREATE OR REPLACE FUNCTION public.referrals_daily_sweep()
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
  r record;
  processed integer := 0;
BEGIN
  FOR r IN
    SELECT DISTINCT e.referred_user_id, NULL::uuid AS org_id
    FROM public.referral_events e
    LEFT JOIN public.referral_rewards rr
      ON rr.referred_user_id = e.referred_user_id
    WHERE e.status = 'booked'
      AND e.referred_user_id IS NOT NULL
      AND rr.id IS NULL
  LOOP
    PERFORM public.issue_referral_reward_once(r.referred_user_id, r.org_id);
    processed := processed + 1;
  END LOOP;
  RETURN processed;
END;
$$;
