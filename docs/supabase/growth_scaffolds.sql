-- Growth scaffolds: tables, helper RPC, and KPI views
-- Safe to run multiple times (IF NOT EXISTS / CREATE OR REPLACE VIEW)
-- Verification (post-run):
--   select to_regclass('public.pricing_plans');
--   select to_regclass('public.referral_codes');
--   select to_regclass('public.onboarding_progress');
--   select to_regclass('public.marketplace_demo_loads');

-- Extension (uuid, if not present)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1) Pricing plans
CREATE TABLE IF NOT EXISTS public.pricing_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id text NOT NULL,                   -- e.g., free, pro_driver, pro_broker, pro_fleet, enterprise
  audience text NOT NULL,                  -- driver | broker | fleet | org | user
  name text NOT NULL,
  description text,
  price_cents integer NOT NULL DEFAULT 0,
  currency text NOT NULL DEFAULT 'USD',
  billing_interval text NOT NULL DEFAULT 'month',  -- month|year
  price_id text,                           -- Stripe price id (optional mapping)
  features jsonb DEFAULT '{}'::jsonb,
  is_active boolean NOT NULL DEFAULT true,
  sort_order integer DEFAULT 100,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_pricing_plans_plan_audience ON public.pricing_plans(plan_id, audience);
CREATE INDEX IF NOT EXISTS idx_pricing_plans_active ON public.pricing_plans(is_active);

-- 2) Referral codes + events + credit ledger
CREATE TABLE IF NOT EXISTS public.referral_codes (
  code text PRIMARY KEY,
  issuer_user_id uuid NOT NULL,
  issuer_org_id uuid,
  audience text NOT NULL,                  -- driver | fleet | broker (target audience)
  max_uses integer NOT NULL DEFAULT 100,
  uses integer NOT NULL DEFAULT 0,
  expires_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_referral_codes_issuer ON public.referral_codes(issuer_user_id);
CREATE INDEX IF NOT EXISTS idx_referral_codes_audience ON public.referral_codes(audience);

CREATE TABLE IF NOT EXISTS public.referral_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL REFERENCES public.referral_codes(code) ON DELETE CASCADE,
  referred_user_id uuid,
  status text NOT NULL,                    -- clicked | signed_up | booked
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_referral_events_code ON public.referral_events(code);
CREATE INDEX IF NOT EXISTS idx_referral_events_status ON public.referral_events(status);
CREATE INDEX IF NOT EXISTS idx_referral_events_day ON public.referral_events((date_trunc('day', created_at)));

CREATE TABLE IF NOT EXISTS public.credit_ledger (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  amount_cents integer NOT NULL,           -- positive credit; negative debit if needed later
  reason text NOT NULL,                    -- e.g., referral_booking
  meta jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_credit_ledger_user ON public.credit_ledger(user_id);
CREATE INDEX IF NOT EXISTS idx_credit_ledger_reason ON public.credit_ledger(reason);

-- Helper RPC used by referral_redeem to increment uses safely
CREATE OR REPLACE FUNCTION public.referral_increment_use(p_code text)
RETURNS void
LANGUAGE sql
AS $$
  UPDATE public.referral_codes
     SET uses = uses + 1
   WHERE code = p_code;
$$;

-- 3) Broker promotions
CREATE TABLE IF NOT EXISTS public.broker_promotions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL,
  promo_type text NOT NULL,               -- e.g., boosted_listing
  quota integer NOT NULL DEFAULT 0,
  used integer NOT NULL DEFAULT 0,
  active boolean NOT NULL DEFAULT true,
  valid_from timestamptz,
  valid_to timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_broker_promotions_org ON public.broker_promotions(org_id);
CREATE INDEX IF NOT EXISTS idx_broker_promotions_type ON public.broker_promotions(promo_type);

CREATE TABLE IF NOT EXISTS public.promotion_applied (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  promotion_id uuid NOT NULL REFERENCES public.broker_promotions(id) ON DELETE CASCADE,
  org_id uuid NOT NULL,
  load_id text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_promotion_applied_org ON public.promotion_applied(org_id);
CREATE INDEX IF NOT EXISTS idx_promotion_applied_load ON public.promotion_applied(load_id);

-- 4) Onboarding progress
CREATE TABLE IF NOT EXISTS public.onboarding_progress (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  org_id uuid,
  flow text NOT NULL,                      -- 'org' | 'driver' | etc.
  step text NOT NULL,                      -- e.g., company | invites | integrations | first_watch
  completed boolean NOT NULL DEFAULT false,
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_onboarding_progress_user ON public.onboarding_progress(user_id, flow);
CREATE INDEX IF NOT EXISTS idx_onboarding_progress_org ON public.onboarding_progress(org_id);
CREATE INDEX IF NOT EXISTS idx_onboarding_progress_step ON public.onboarding_progress(step, completed);

-- 5) Demo loads table (for marketplace bootstrapping)
CREATE TABLE IF NOT EXISTS public.marketplace_demo_loads (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  broker_name text NOT NULL DEFAULT 'Demo Broker',
  origin_city text,
  origin_state text,
  dest_city text,
  dest_state text,
  pickup_start timestamptz,
  pickup_end timestamptz,
  equipment text,
  rate_usd numeric,
  cpm_est numeric,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_marketplace_demo_loads_state ON public.marketplace_demo_loads(origin_state, dest_state);
CREATE INDEX IF NOT EXISTS idx_marketplace_demo_loads_created ON public.marketplace_demo_loads(created_at DESC);

-- 6) KPI views
-- Referrals KPI: daily series of clicks, signups, bookings, plus total uses
CREATE OR REPLACE VIEW public.kpi_referrals AS
SELECT
  date_trunc('day', e.created_at) AS day,
  sum(CASE WHEN e.status = 'clicked' THEN 1 ELSE 0 END) AS clicks,
  sum(CASE WHEN e.status = 'signed_up' THEN 1 ELSE 0 END) AS signups,
  sum(CASE WHEN e.status = 'booked' THEN 1 ELSE 0 END) AS bookings,
  count(*) AS total_events
FROM public.referral_events e
GROUP BY 1
ORDER BY 1 DESC;

-- Onboarding KPI: counts by flow/step and completion flag
CREATE OR REPLACE VIEW public.kpi_onboarding AS
SELECT
  flow,
  step,
  sum(CASE WHEN completed THEN 1 ELSE 0 END) AS completed_count,
  sum(CASE WHEN NOT completed THEN 1 ELSE 0 END) AS pending_count,
  count(*) AS total,
  max(updated_at) AS last_update
FROM public.onboarding_progress
GROUP BY 1,2
ORDER BY 1,2;

-- Optional grants (adapt to your RLS model)
-- GRANT SELECT ON public.kpi_referrals, public.kpi_onboarding TO anon, authenticated;