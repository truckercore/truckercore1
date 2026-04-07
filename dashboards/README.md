# Webhooks Dashboards

Primary stack: Prometheus + Grafana
Optional: Datadog (gated by DATADOG_ENABLED=true)

Import the provided Grafana dashboard JSON:
- dashboards/webhooks_overview.json

Metrics expected (emitted by api/lib/webhook.ts):
- webhook_verify_total{result, endpoint, secret_version?, key_id?}
- webhook_verify_duration_seconds (histogram/summary preferred) with {endpoint}
- webhook_secret_match_total{endpoint, matched, secret_version, key_id}
- replay_total{endpoint, topic}
- provider_version_drift_total{endpoint, got_version}
- webhook_rotation_next_no_traffic_total{endpoint, window}
- webhook_abuse_ban_total{endpoint}

Key panels:
- Secret version match rate: rate(webhook_secret_match_total{matched="next"}[5m]) / (rate(webhook_secret_match_total[5m]) > 0)
- Skew histogram: derive from logs or expose ts_skew_ms as a histogram; else show invalid=skew rate
- Reject reasons by endpoint/provider: sum by (result, endpoint) (rate(webhook_verify_total[5m]))
- Verification latency: histogram_quantile(0.95, sum by (le, endpoint) (rate(webhook_verify_duration_seconds_bucket[5m])))
- Invalid and replay rates: sum by (endpoint) (rate(webhook_verify_total{result="invalid"}[5m])) and rate(replay_total[5m])

Datadog: Create equivalent monitors and dashboards; use DATADOG_ENABLED to guard exporters.
