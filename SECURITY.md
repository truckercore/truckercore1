# Security Policy

We take security seriously and appreciate responsible disclosure.

## Reporting a Vulnerability
- Email: security@example.com (preferred)
- Backup: open a private security advisory via GitHub (Security → Advisories → New draft advisory)
- Please include: affected versions/commits, reproduction steps, impact assessment, and any suggested fixes.
- We aim to acknowledge within 2 business days and provide a triage update within 5 business days.

## Supported Versions
During the pilot, we support the latest main branch. After GA, we expect to support the latest minor release and the previous one.

| Version | Supported |
|---------|-----------|
| main    | Yes       |
| <1.0.x  | No        |

## Handling of Secrets
- Never commit service keys to the repository.
- Use environment variables and GitHub Encrypted Secrets.
- Rotation: track in `public.secrets_metadata` (see migrations) and alert on stale secrets.

## RLS and Data Access
- All public tables must have Row Level Security enabled.
- Policies must align with JWT claims: `app_org_id`, `sub`, and role claims (e.g., `app_roles`).
- See docs/rls/ASSERTIONS.sql for verification queries.

---

## Webhooks Security Summary

Providers covered
- Custom HMAC (default), plus profiles for Stripe, GitHub, Slack, and Twilio (see docs/providers/).

Verification contract
- HMAC-SHA256 with path-and-method binding (v2): MAC over `METHOD|path|timestamp|canonical_json_body`.
- Timestamp header accepts unix-seconds or ISO8601; rejects millisecond-epoch values.
- Constant-time signature compare; strict JSON canonicalization; Content-Length validated against raw bytes.

Clock skew window
- Default ±60 seconds. Requests outside this window are rejected.

Secret rotation policy
- Dual-secret overlap: current and next are both accepted until next_expires_at; metrics tag which secret matched.

Replay TTLs
- Topic-based defaults: payments/docs 24h; generic 10m; always ≥ skew window.

Observability and runbooks
- Dashboards: dashboards/webhooks_overview.json (Grafana)
- Alerts: alerts/slo_thresholds.yaml and alerts/anomaly/
- Runbooks: runbooks/ (webhooks verification and rotation), POSTMORTEM_TEMPLATE.md, ops/PIR_CHECKLIST.md
