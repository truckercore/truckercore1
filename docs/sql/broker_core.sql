-- broker_core.sql
-- Unified Broker Dashboard data model (tenders, quotes, routes, invoices, plus dashboard view)

DO $$ BEGIN
  CREATE TYPE tender_status AS ENUM ('draft','open','quoted','awarded','in_transit','delivered','cancelled');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

ALTER TABLE IF EXISTS tenders
  ADD COLUMN IF NOT EXISTS broker_org_id uuid,
  ADD COLUMN IF NOT EXISTS shipper_org_id uuid,
  ADD COLUMN IF NOT EXISTS status tender_status DEFAULT 'draft';

CREATE INDEX IF NOT EXISTS idx_tenders_broker_status ON tenders(broker_org_id, status);
CREATE INDEX IF NOT EXISTS idx_tenders_shipper_status ON tenders(shipper_org_id, status);

ALTER TABLE IF EXISTS tender_quotes
  ADD COLUMN IF NOT EXISTS status text DEFAULT 'proposed',    -- 'proposed','accepted','declined'
  ADD COLUMN IF NOT EXISTS price_cents bigint;

CREATE INDEX IF NOT EXISTS idx_tq_tender ON tender_quotes(tender_id);
CREATE INDEX IF NOT EXISTS idx_tq_status ON tender_quotes(status);

CREATE MATERIALIZED VIEW IF NOT EXISTS mv_route_latest AS
SELECT re.route_id,
       max(re.ts) AS last_event_ts,
       (array_agg(re.event ORDER BY re.ts DESC))[1] AS last_event,
       (array_agg(re.meta ORDER BY re.ts DESC))[1] AS last_meta
FROM route_events re
GROUP BY re.route_id
WITH NO DATA;

CREATE OR REPLACE PROCEDURE refresh_mv_route_latest()
LANGUAGE sql AS $$ REFRESH MATERIALIZED VIEW CONCURRENTLY mv_route_latest $$;

CREATE OR REPLACE VIEW v_broker_dashboard AS
WITH q AS (
  SELECT tq.tender_id,
         count(*) FILTER (WHERE tq.status='proposed') AS quotes_total,
         min(tq.price_cents) AS lowest_quote_cents
  FROM tender_quotes tq GROUP BY tq.tender_id
), live AS (
  SELECT r.load_id, l.last_event_ts, l.last_event, l.last_meta
  FROM routes r
  JOIN mv_route_latest l ON l.route_id = r.id
)
SELECT t.id AS tender_id, t.status AS tender_status, t.created_at,
       q.quotes_total, q.lowest_quote_cents,
       live.last_event_ts, live.last_event,
       i.id AS invoice_id, i.status AS invoice_status, i.total_cents
FROM tenders t
LEFT JOIN q ON q.tender_id = t.id
LEFT JOIN loads ld ON ld.tender_id = t.id
LEFT JOIN live ON live.load_id = ld.id
LEFT JOIN invoices i ON i.tender_id = t.id
WHERE t.broker_org_id = current_org_id();

-- RLS
ALTER TABLE IF EXISTS tenders ENABLE ROW LEVEL SECURITY;
CREATE POLICY broker_tenders_ro ON tenders
  FOR SELECT USING (same_org(broker_org_id));
CREATE POLICY broker_tenders_rw ON tenders
  FOR ALL USING (same_org(broker_org_id) AND is_org_admin())
  WITH CHECK (same_org(broker_org_id));

ALTER TABLE IF EXISTS tender_quotes ENABLE ROW LEVEL SECURITY;
CREATE POLICY broker_quotes_ro ON tender_quotes
  FOR SELECT USING (
    EXISTS(SELECT 1 FROM tenders t WHERE t.id=tender_quotes.tender_id AND same_org(t.broker_org_id))
  );
CREATE POLICY broker_quotes_rw ON tender_quotes
  FOR ALL USING (
    EXISTS(SELECT 1 FROM tenders t WHERE t.id=tender_quotes.tender_id AND same_org(t.broker_org_id)) AND is_org_admin()
  )
  WITH CHECK (true);

ALTER TABLE IF EXISTS invoices ENABLE ROW LEVEL SECURITY;
CREATE POLICY broker_invoices_ro ON invoices
  FOR SELECT USING (same_org(broker_org_id));
CREATE POLICY broker_invoices_rw ON invoices
  FOR ALL USING (same_org(broker_org_id) AND is_org_admin())
  WITH CHECK (same_org(broker_org_id));
