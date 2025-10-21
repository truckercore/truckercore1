-- perf_indexes.sql
-- Indices & housekeeping (performance you’ll want)

CREATE INDEX IF NOT EXISTS idx_carriers_dot ON carriers(dot_number);
CREATE INDEX IF NOT EXISTS idx_cts_score ON carrier_trust_scores(score DESC);
CREATE INDEX IF NOT EXISTS idx_cv_carrier_time ON carrier_verifications(carrier_id, performed_at DESC);
CREATE INDEX IF NOT EXISTS idx_we_provider_event ON webhook_events(provider, event_id);
CREATE INDEX IF NOT EXISTS idx_bridges_key ON data_bridges(provider, type, external_id);
