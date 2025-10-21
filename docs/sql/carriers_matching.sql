-- carriers_matching.sql
-- Smart Load Matching (AI) + Carrier Trust

CREATE TABLE IF NOT EXISTS carriers(
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL,
  legal_name text NOT NULL,
  dot_number text, mc_number text,
  created_at timestamptz DEFAULT now(),
  UNIQUE(dot_number)
);
ALTER TABLE carriers ENABLE ROW LEVEL SECURITY;
CREATE POLICY carriers_ro ON carriers FOR SELECT USING (true);
CREATE POLICY carriers_rw ON carriers FOR ALL USING (is_org_admin()) WITH CHECK (true);

CREATE TABLE IF NOT EXISTS carrier_profiles(
  carrier_id uuid PRIMARY KEY REFERENCES carriers(id) ON DELETE CASCADE,
  equipment text[],
  home_base jsonb,
  lanes jsonb,
  contact jsonb,
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS carrier_compliance(
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  carrier_id uuid REFERENCES carriers(id) ON DELETE CASCADE,
  insurance_status text, insurance_expiry date,
  safety_rating text, last_fmcsa_pull timestamptz,
  ifta_good boolean,
  created_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_cc_carrier ON carrier_compliance(carrier_id);

CREATE TABLE IF NOT EXISTS carrier_perf(
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  carrier_id uuid REFERENCES carriers(id) ON DELETE CASCADE,
  on_time_pct numeric, cancel_rate numeric, claims_count int, last_90d_loads int,
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS carrier_trust_scores(
  carrier_id uuid PRIMARY KEY REFERENCES carriers(id) ON DELETE CASCADE,
  score numeric NOT NULL,
  factors jsonb,
  refreshed_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS match_candidates(
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  load_id uuid NOT NULL REFERENCES loads(id) ON DELETE CASCADE,
  carrier_id uuid NOT NULL REFERENCES carriers(id) ON DELETE CASCADE,
  score numeric NOT NULL,
  reasons text[] NOT NULL DEFAULT '{}',
  created_at timestamptz DEFAULT now(),
  UNIQUE(load_id, carrier_id)
);
CREATE INDEX IF NOT EXISTS idx_mc_load ON match_candidates(load_id);
CREATE INDEX IF NOT EXISTS idx_mc_score ON match_candidates(score DESC);

ALTER TABLE match_candidates ENABLE ROW LEVEL SECURITY;
CREATE POLICY mc_ro ON match_candidates
  FOR SELECT USING (
    EXISTS(SELECT 1 FROM loads l JOIN tenders t ON t.id=l.tender_id
           WHERE l.id=match_candidates.load_id AND same_org(t.broker_org_id))
  );
REVOKE ALL ON match_candidates FROM anon, authenticated;

CREATE TABLE IF NOT EXISTS carrier_verifications(
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  carrier_id uuid REFERENCES carriers(id) ON DELETE CASCADE,
  check_type text NOT NULL,
  result text NOT NULL,
  evidence_url text,
  performed_at timestamptz DEFAULT now()
);

CREATE OR REPLACE FUNCTION can_award_to_carrier(p_carrier uuid, p_min_score numeric)
RETURNS boolean
LANGUAGE sql SECURITY DEFINER SET search_path=public AS $$
  SELECT coalesce((SELECT score FROM carrier_trust_scores WHERE carrier_id=p_carrier),0) >= p_min_score
     AND NOT EXISTS (SELECT 1 FROM carrier_verifications WHERE carrier_id=p_carrier AND result='fail')
$$;