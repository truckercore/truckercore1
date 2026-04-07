# Dashboard: Webhook Health

Charts
- webhook_verify_total by result (ok, invalid, skew, replay, idempotent)
- webhook_verify_duration_seconds P50/P95
- Delivery attempts vs successes vs failures per endpoint/org
- Retry/backoff distribution and age of in-flight deliveries

Breakdowns
- By endpoint URL, org_id, topic

SLOs
- Verify P95 < 50ms; invalid+skew+replay ratio < 0.5%; delivery success > 99%

Links
- Alerts: webhook signature failures, replay spikes
- Runbook: runbooks/webhook_abuse.md
