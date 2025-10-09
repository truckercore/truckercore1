# Webhook Chaos Drills (Staging Only)

Safety first: These drills default to dry-run mode and should be executed in staging with CHAOS_ENABLED=false unless explicitly approved.

Scenarios:
- Secret compromise: rotate secret, ensure next is accepted, and current rejected after cutover.
- Pin expiry: simulate certificate pin expiration on agents; verify mTLS fallback and alerting.
- Provider IP drift: emulate requests from new/unknown ranges and confirm allowlist decisions + logging.
- Queue backlog: simulate enqueue delays and verify visibility timeout/backoff behavior.

Environment variables:
- CHAOS_ENABLED=false (required for dry-run)
- ENV=staging (target environment)
- WEBHOOK_PROVIDER=stripe|github|slack|twilio|custom
- ENDPOINT_URL=https://staging.example.com/webhooks/test
- SECRET_CURRENT=...
- SECRET_NEXT=...

Run:
node chaos/drills/secret_compromise.mjs
node chaos/drills/pin_expiry.mjs
node chaos/drills/provider_ip_drift.mjs
node chaos/drills/queue_backlog.mjs

Notes:
- All scripts log steps and required manual approvals before any real changes.
- Integrate with CI: schedule quarterly, but keep dry-run unless a maintainer flips CHAOS_ENABLED=true with change management approval.
