# Runbook: Webhook Secret Rotation and Drift Enforcement

Owner: Webhooks On-Call (webhooks-oncall@example.com)
Environment: staging, prod

1) Overview
- Purpose: Rotate webhook signing secrets safely, ensure cutover, and prevent drift.
- Scope: All outbound webhook subscriptions and inbound receivers using HMAC sha256 over `${timestamp}.${rawBody}` with `sha256=` prefix.

2) Rotation Plan
- T-7 to T-1 days: Generate new secret (S_next) and store as `nextSecret` for each subscription with `nextSecretExpiresAt` set to cutover time (UTC).
- T-0 (cutover): Delivery service begins signing with S_next; receivers accept both S_cur and S_next if `timestamp <= nextSecretExpiresAt`.
- T+1: Promote S_next to current; clear `nextSecret` fields. Invalidate S_cur.

3) Enforcement Job
- Schedule scripts/webhooks/rotation_enforcer.mjs (or equivalent) to run every 5 minutes:
  - Find subscriptions where `nextSecret` is set and `nextSecretExpiresAt < now()`.
  - Disable/clear `nextSecret` and set `secret = nextSecret` if not already promoted.
  - Alert on drift (any sub still using `secret` != promoted value 10+ minutes after cutover).

4) Alerting & Monitoring
- Metrics: webhook_verify_total{result=ok|invalid|skew|replay|idempotent_duplicate, endpoint}
- Latency: webhook_verify_duration_seconds{quantile}
- Alerts:
  - Spike in {result="invalid"} or {result="skew"} > SLO for 5 min.
  - Any replay/idempotent_duplicate increase sustained for 10 min.
- Dashboards: Track verification results per endpoint, 95p duration.

5) Incident Response (Compromised Secret)
- Containment: Set new `nextSecret` immediately with short cutover (<=5 min). Notify partners.
- Rotate: Force cutover at T-0; revoke old secret. Consider temporarily reducing skew window.
- Monitor: Watch invalid/skew metrics and delivery failures.
- Post-incident: Audit access, update THREAT_MODEL.md, and improve storage/process.

6) Validation
- CI Canary: `npm run security:verify-webhooks` validates HMAC format, timestamp skew rejection (>5 min), and replay denial.
- Staging test: Use sample receiver (api/samples/webhook_receiver.ts) with InMemoryReplayCache or persistent cache.

7) Rollback
- If cutover fails, extend `nextSecretExpiresAt` and continue dual-acceptance window while investigating.

8) References
- api/lib/webhook.ts – verify(), SupabaseTTLCache, metrics
- scripts/webhooks/rotation_enforcer.mjs – enforcer scaffold
- docs/SECRETS.md, docs/LOGGING.md, docs/ALERTS.md
