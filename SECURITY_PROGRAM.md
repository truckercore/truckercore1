# Security Program (SSDLC) – TruckerCore

This document defines the minimum security baselines and practices to integrate into daily development.

1) Baselines
- Language/framework guides: Node/TS (server), Flutter/Dart (mobile), SQL (Supabase). Adopt security checklists per stack.
- Secure PR checklist: use .github/PULL_REQUEST_TEMPLATE.md.
- Secrets handling: see docs/SECRETS.md. Never commit secrets; use environment stores. Logs are redacted by api/lib/logging.ts.
- Dependency policy: pin via lockfiles, review Renovate PRs weekly, run SCA in CI and nightly.

2) Gateways
- Threat modeling at feature kickoff; capture in THREAT_MODEL.md (or per-feature copies).
- Security sign-off required for risky changes (auth, payments, PII, crypto, RLS/policies).
- Mandatory PR reviews by at least one code owner.
- CI gates: type checks, lint, unit tests, SAST (Semgrep), SCA (npm audit with high+ threshold).

3) Training
- Annual secure coding training requirement.
- Just-in-time reviewer guidance embedded in PR template and checklists.

4) Vulnerability Management
- SCA/SAST on every PR and on nightlies. High/Critical break the build.
- SLA: Critical 24h, High 7d, Medium 30d, Low 90d. Track exceptions with risk acceptance in issues.
- Renovate opens automated PRs with tests.

5) Security Testing
- Unit/integration tests for authZ/authN, RLS policies, and webhook verification (signature/skew/replay/idempotency).
- Secret-safety tests (golden-file checks) ensure no logs leak secrets.
- DAST template added; wire to staging with auth for release candidates.
- Annual external pen test and after major architectural changes.
- Misuse/abuse test stubs for rate-limit bypass, CSRF/SSRF, IDOR.

6) Data Minimization & Retention
- Maintain docs/DATA_INVENTORY.md per feature with purpose, retention, lawful basis.
- Collect only required data; avoid free‑form PII.
- Pseudonymize where possible; segregate analytics from ops data.
- Retention via SQL purge function (see supabase/migrations/2025-09-26_data_retention.sql) and scheduler.

7) Encryption
- In transit: enforce HTTPS/TLS 1.2+, HSTS for web.
- At rest: managed storage encryption; encrypt highly sensitive fields at the app layer, with key rotation. Scaffold to follow.
- Key management: separate envs, least-privilege KMS access, rotation schedule, audit logs.

8) Access Control
- Centralized authorization: default deny; role/attribute checks; org scoping (api/lib/guard.ts) and DB RLS.
- Session security: short-lived tokens, refresh rotation, secure/HttpOnly/SameSite cookies.
- Admin/service accounts: least privilege, MFA, break-glass with auditing (see runbooks).

9) Detection, Monitoring, Alerting
- Logging: structured, immutable logs with redaction (api/lib/logging.ts). Correlation IDs required. See docs/LOGGING.md.
- Monitoring: central ingestion + dashboards; anomaly detection for auth failures, rate-limits, unusual access.
- Alerting: severity model and on-call rotations. See docs/ALERTS.md.

10) Governance
- SECURITY.md holds high-level policy; this file holds practical SSDLC.
- README points to these docs; CI enforces minimum gates.


## Webhook Security Operations

- Threat modeling: see THREAT_MODEL.md and tests under tests/ for verification, replay, and rotation scenarios.
- Provider profiles: docs/providers/ (documented headers, timestamp formats, signature schemes, versioning, and test links).
- Chaos drills: chaos/drills/ (staging-only; dry-run by default via CHAOS_ENABLED=false).
- Red-team automation: tooling/redteam/webhook_rt.mjs (cross-endpoint replay and downgrade tests).
- Observability:
  - Metrics: docs/metrics/webhooks.md
  - Dashboards: dashboards/webhooks_overview.json (Grafana)
  - Alerts: alerts/slo_thresholds.yaml and alerts/anomaly/
- Post-incident: POSTMORTEM_TEMPLATE.md (webhooks sections) and ops/PIR_CHECKLIST.md
