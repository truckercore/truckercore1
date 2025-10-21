# Webhooks Metrics Reference

Emitted by api/lib/webhook.ts

- webhook_verify_total
  - Type: counter
  - Labels: result (ok|invalid|replay|skew|missing_signature|bad_signature_format|content_length_mismatch|unsupported_content_type|idempotent_duplicate), endpoint, secret_version?, key_id?
  - Notes: Primary success/failure counter for dashboards and SLOs.

- webhook_verify_duration_seconds
  - Type: histogram/summary (implementation dependent)
  - Labels: endpoint
  - Notes: Use histogram_quantile for p95 SLO.

- webhook_secret_match_total
  - Type: counter
  - Labels: endpoint, matched (current|next), secret_version (same as matched), key_id (first 6 hex)
  - Notes: Use to track rotation adoption; anomaly alert if next traffic drops.

- replay_total
  - Type: counter
  - Labels: endpoint, topic (payments|docs|generic|custom)
  - Notes: Should remain near zero; alert on spikes.

- provider_version_drift_total
  - Type: counter
  - Labels: endpoint, got_version
  - Notes: Indicates unexpected provider versions.

- webhook_rotation_next_no_traffic_total
  - Type: counter
  - Labels: endpoint, window
  - Notes: Fires when nextSecret near expiry but no verifying traffic.

- webhook_abuse_ban_total
  - Type: counter
  - Labels: endpoint
  - Notes: AbuseGuard bans due to invalid bursts.
