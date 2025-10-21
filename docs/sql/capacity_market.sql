-- capacity_market.sql
-- Dynamic Capacity Marketplace

CREATE TABLE IF NOT EXISTS capacity_posts(
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  carrier_id uuid REFERENCES carriers(id) ON DELETE CASCADE,
  org_id uuid NOT NULL,
  lane jsonb NOT NULL,                          -- {origin:"CHI",dest:"DAL"}
  equipment text NOT NULL,
  available_from date, available_to date,
  min_rate_cpm numeric,
  visibility text DEFAULT 'brokers',
  created_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_capacity_org ON capacity_posts(org_id);
CREATE INDEX IF NOT EXISTS idx_capacity_lane ON capacity_posts((lane->>'origin'), (lane->>'dest'));

ALTER TABLE capacity_posts ENABLE ROW LEVEL SECURITY;
CREATE POLICY cp_carrier_rw ON capacity_posts
  FOR ALL USING (same_org(org_id)) WITH CHECK (same_org(org_id));
CREATE POLICY cp_broker_ro ON capacity_posts
  FOR SELECT USING (current_role() LIKE '%broker%' OR visibility='brokers');
