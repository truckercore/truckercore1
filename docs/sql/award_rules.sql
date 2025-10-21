-- award_rules.sql
-- Enforcement: award guard + idempotent award RPC

CREATE OR REPLACE FUNCTION award_quote_if_trusted(p_tender uuid, p_carrier uuid, p_min_score numeric DEFAULT 70)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE qid uuid;
BEGIN
  IF NOT can_award_to_carrier(p_carrier, p_min_score) THEN
    RAISE EXCEPTION 'Carrier trust/verification failed' USING errcode = 'P0001';
  END IF;

  SELECT id INTO qid FROM tender_quotes
  WHERE tender_id = p_tender AND carrier_id = p_carrier
  ORDER BY price_cents ASC LIMIT 1;

  IF qid IS NULL THEN
    RAISE EXCEPTION 'No quote by carrier';
  END IF;

  UPDATE tender_quotes SET status='accepted' WHERE id=qid AND status <> 'accepted';
  UPDATE tender_quotes SET status='declined' WHERE tender_id=p_tender AND carrier_id <> p_carrier AND status <> 'declined';
  UPDATE tenders SET status='awarded' WHERE id=p_tender AND status IN ('open','quoted');

  RETURN qid;
END $$;
