-- carrier_verif_webhook.sql
-- Carrier Verification Engine / Fraud Prevention (webhook sink)

CREATE TABLE IF NOT EXISTS kyc_webhook_events(
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor text NOT NULL, event_id text, headers jsonb, payload jsonb NOT NULL,
  received_at timestamptz DEFAULT now(),
  processed boolean DEFAULT false,
  UNIQUE(vendor, event_id)
);
ALTER TABLE kyc_webhook_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY kyc_ro ON kyc_webhook_events FOR SELECT USING (is_org_admin());
REVOKE ALL ON kyc_webhook_events FROM anon, authenticated;
