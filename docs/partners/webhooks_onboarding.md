# Partner Webhooks – One-Page Onboarding

Audience: Integration engineers at providers sending events to TruckerCore.

What you send
- Endpoint: Provided per partner (staging and production). For tests, use: https://staging.truckercore.app/webhooks/test
- Method: POST
- Content-Type: application/json
- Body: JSON payload matching your provider profile (see docs/providers/). Keep payload minimal; include IDs and fetch sensitive data via authenticated API when needed.

Required headers
- x-truckercore-signature: sha256 HMAC signature (see scheme below)
- x-truckercore-timestamp: UNIX seconds (preferred) or ISO8601 (e.g., 2025-09-26T14:31:00Z)
- idempotency-key: A unique key per event delivery attempt (min length 8). Reuse the same key when retrying the same event.

Signature scheme (v2)
- Compute canonical JSON (stable key ordering, UTF-8, LF line endings).
- MAC input: METHOD|path|timestamp|canonical_json
- Signature: sha256=HMAC_SHA256(secret_scoped, input)
- Secret scoping: We derive per-org/per-endpoint keys internally via HKDF; you only manage your org’s secret.

Skew, replay, and retries
- Clock skew window: ±60 seconds. Do not send timestamps outside this window.
- Replay protection: We reject duplicate signature/timestamp pairs. TTL defaults:
  - payments/docs: 24h
  - generic: 10m
- Retry policy: Exponential backoff with jitter is recommended (e.g., start at 1s, cap at 1–5 min; stop after ~24h for payments/docs, ~30m for generic). Use the same idempotency-key when retrying the same event.

Status codes
- 2xx: Accepted (enqueue & process async). Safe to stop retrying.
- 4xx: Do not retry unless noted (e.g., 409 idempotency mismatch).
- 5xx or network failures: Retry with backoff and same idempotency-key.

Testing
- Staging test endpoint (no side effects): https://staging.truckercore.app/webhooks/test
- Use the manual “Webhooks Security Ops (manual)” workflow (GitHub Actions) to run synthetic checks and chaos drills in dry-run.
- See tests/webhook_verification.spec.ts for examples of signing and expected failures.

Observability & support
- Dashboards: dashboards/webhooks_overview.json (Grafana)
- Alerts: alerts/slo_thresholds.yaml (Prometheus)
- Runbooks: runbooks/
- Contact: security@example.com

FAQ
- Do you support Stripe/GitHub/Slack/Twilio formats? Yes; see docs/providers/.
- Do you accept ISO8601 timestamps? Yes; we also accept UNIX seconds. Millisecond-epoch integers are rejected.
- Can we send text/plain? Not by default; application/json is required unless explicitly allowlisted.
