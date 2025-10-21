# Standardized Detections and Alert Catalog

Signals (with example metrics/log sources and default severity)

Authentication
- Failed login bursts: auth_failed_total rate > threshold per org and global. Sev: High.
- Token refresh failures: refresh_error_total rate spike. Sev: Medium.
- Suspicious MFA bypass attempts: mfa_bypass_total > 0. Sev: High.

API/Service Health
- 5xx spikes: http_requests_total{status=~"5.."} error budget burn; SLO based. Sev: High/Critical.
- 4xx anomalies: http_requests_total{status=~"4.."} unexpected spike for sensitive endpoints. Sev: Medium.
- Latency regressions: http_request_duration_seconds P95/P99 > SLO. Sev: Medium/High.

RLS/Authorization
- Unusual RLS policy denials: rls_denied_total rate > baseline for an org/user. Sev: Medium.
- Admin/privileged actions: audit_privileged_total > 0 outside change window. Sev: High.

Webhooks
- Signature invalid/skew/replay: webhook_verify_total{result=~"invalid|skew|replay|idempotent"} > threshold. Sev: Medium/High.
- Delivery failures: webhook_delivery_failures_total rate spike. Sev: Medium.

Security Operations
- Secret scanning findings in CI: secrets_found_total > 0. Sev: High.
- Dependency vulnerabilities (High/Critical) detected: sca_vulns_high_total > 0. Sev: High.

Routing and Suppressions
- Critical -> on-call page immediately.
- High -> security triage queue; page during business hours unless correlated with Critical service health.
- Medium/Low -> ticket backlog with weekly review.
- Suppress correlated cascades using multi-window deduplication; use 5–10 min mute windows during ongoing incidents.

SLO-based Thresholds
- Start with rolling 7-day baselines and set thresholds at +3σ; refine from incident learnings.
