-- External feeds dead-letter aggregation table
-- Stores unique error signatures per feed and counts occurrences for alerting

CREATE TABLE IF NOT EXISTS external_feeds_errors (
  feed_key text NOT NULL,
  error_hash text NOT NULL,
  last_error text,
  seen_at timestamptz NOT NULL DEFAULT now(),
  count integer NOT NULL DEFAULT 1,
  PRIMARY KEY (feed_key, error_hash)
);

CREATE INDEX IF NOT EXISTS idx_external_feeds_errors_seen ON external_feeds_errors(seen_at DESC);
