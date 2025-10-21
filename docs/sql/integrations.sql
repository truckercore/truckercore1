-- integrations.sql
-- Open API Layer + Webhooks for TMS/ELD (HMAC, idempotent, provider mapping)

CREATE TABLE IF NOT EXISTS provider_accounts(
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL,
  provider text NOT NULL,        -- 'eld:keeptruckin','tms:project44', etc.
  creds_ref text,
  status text NOT NULL DEFAULT 'active',
  created_at timestamptz DEFAULT now(),
  UNIQUE(org_id, provider)
);
ALTER TABLE provider_accounts ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_provider_accounts_org ON provider_accounts(org_id);
CREATE POLICY pa_ro ON provider_accounts FOR SELECT USING (same_org(org_id));
CREATE POLICY pa_rw ON provider_accounts FOR ALL USING (same_org(org_id) AND is_org_admin()) WITH CHECK (same_org(org_id));

CREATE TABLE IF NOT EXISTS webhook_events(
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider text NOT NULL,
  topic text,
  event_id text,
  headers jsonb,
  payload jsonb NOT NULL,
  received_at timestamptz DEFAULT now(),
  signature_valid boolean DEFAULT false,
  processed boolean DEFAULT false,
  UNIQUE(provider, event_id)
);

CREATE TABLE IF NOT EXISTS data_bridges(
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider text NOT NULL,
  type text NOT NULL,            -- 'vehicle','driver','load','doc'
  external_id text NOT NULL,
  internal_ref uuid NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE(provider, type, external_id)
);

ALTER TABLE webhook_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY webhook_ro ON webhook_events FOR SELECT USING (true);
REVOKE ALL ON webhook_events FROM anon, authenticated;

ALTER TABLE data_bridges ENABLE ROW LEVEL SECURITY;
CREATE POLICY db_ro ON data_bridges FOR SELECT USING (true);
