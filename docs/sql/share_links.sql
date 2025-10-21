-- share_links.sql
-- Real-time tracking share links (read-only tokenized map)

CREATE TABLE IF NOT EXISTS share_links(
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  load_id uuid NOT NULL REFERENCES loads(id) ON DELETE CASCADE,
  token_hash text NOT NULL,
  expires_at timestamptz NOT NULL,
  created_by uuid,
  created_at timestamptz DEFAULT now(),
  revoked boolean DEFAULT false
);
CREATE INDEX IF NOT EXISTS idx_share_links_load ON share_links(load_id);
CREATE INDEX IF NOT EXISTS idx_share_links_exp ON share_links(expires_at);

ALTER TABLE share_links ENABLE ROW LEVEL SECURITY;
CREATE POLICY sl_ro ON share_links FOR SELECT USING (
  EXISTS(SELECT 1 FROM loads l JOIN tenders t ON t.id=l.tender_id
         WHERE l.id=share_links.load_id AND (same_org(t.broker_org_id) OR same_org(t.shipper_org_id)))
);
CREATE POLICY sl_rw ON share_links FOR ALL USING (
  EXISTS(SELECT 1 FROM loads l JOIN tenders t ON t.id=l.tender_id
         WHERE l.id=share_links.load_id AND (same_org(t.broker_org_id) OR same_org(t.shipper_org_id))) AND is_org_admin()
) WITH CHECK (true);

CREATE OR REPLACE FUNCTION validate_share_token(p_load uuid, p_token text)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE ok boolean;
BEGIN
  ok := EXISTS(
    SELECT 1 FROM share_links
    WHERE load_id=p_load
      AND token_hash = encode(digest(p_token,'sha256'),'hex')
      AND expires_at > now()
      AND revoked = false
  );
  RETURN ok;
END $$;
