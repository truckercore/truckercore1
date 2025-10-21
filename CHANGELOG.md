# Changelog

All notable changes to this project will be documented in this file.

Format (for each entry):
- Date (YYYY-MM-DD)
- Version or commit hash
- Category: Added/Changed/Fixed/Removed
- Details: what/why
- Rollback: clear instructions, if needed

## 2025-09-25
- Commit: Alert dedupe per tenant, TTM KPIs, SECDEF manifest, and drills
- Category: Added
- Details:
  - Alerts: Added per-tenant dedupe/suppression via alert_route_overrides and org-aware dedupe_key/org_id on alert_outbox; enqueue_alert now accepts optional p_org_id (backwards compatible). Migration: 1016_alert_tenant_dedupe_kpi_secdef.sql.
  - KPIs: Added kpi_time_to_ack_7d and kpi_quarantine_ttm_30d views to track time-to-mitigate for alerts and quarantine events.
  - Security: Versioned SECURITY DEFINER function manifests with snapshot_secdef_manifest() and history table; added CI workflow secdef_manifest_snapshot.yml to export/diff.
  - Ops: Added weekly_ttm_kpi.yml to publish Weekly TTM KPI, and rehearse_rollback_gate.yml to enforce periodic rollback/deploy-gate failure drills with evidence verification.
- Rollback:
  - Revert the new workflows (.github/workflows/*ttm_kpi*.yml, *secdef_manifest_snapshot*.yml, *rehearse_rollback_gate*.yml).
  - The SQL migration is idempotent; safe to leave. To back out, you may drop views/tables created in 1016 if desired.

## 2025-09-25
- Commit: Governance + SecDef CI, Marketplace scaling, rollback helper
- Category: Added
- Details:
  - CI: Added Security-Definer hygiene checks (.github/workflows/secdef_checks.yml) using docs/ci/SECDEF_CHECKS.sql to ensure SECURITY DEFINER functions set search_path=public and avoid EXECUTE (with vetted allowlist).
  - CI: Added Governance Manifest export (.github/workflows/governance_manifest.yml) to upload tables, policies, RPCs, and grants as artifacts per PR.
  - CI: Added Quarterly RLS & Grants Revalidation (.github/workflows/quarterly_rls_grants_audit.yml).
  - DB: Added keyset pagination RPCs for marketplace listings and bids (1012_marketplace_keyset_and_limits.sql) and helpful indexes.
  - DB: Added rate-limit guard and idempotency protections for bids (1013_marketplace_rate_limit_idem.sql).
  - DB: Added audit RPCs for privileged API key actions (1014_api_key_audit.sql) writing to function_audit_log and optional api_key_audit table.
  - Scripts: Added one-command rollback script scripts/release/undo.sh and docs/release/ROLLBACK_PREPOST.md.
- Rollback:
  - Remove the above workflows if not desired.
  - Revert migrations 1012–1014 (idempotent; safe to leave in place if not used).
  - Delete scripts/release/undo.sh and the rollback doc if unwanted.

## 2025-09-05
- Commit: CI hardening and toolchain pin
- Category: Added/Changed
- Details:
  - Pinned Flutter 3.35.1 in CI.
  - CI now enforces formatting via dart format and fails fast.
  - Coverage threshold enforced via scripts/coverage_check.dart (>=45%).
  - Added docs/release/versions.md and Setup & Versions section in README.
- Rollback:
  - Revert this commit.
  - If CI fails on format step, switch back to flutter format in .github/workflows/ci.yml (not recommended) or run `dart format .` locally and recommit.

## 2025-09-18
- Version: 1.0.1+2
- Category: Added/Changed
- Details:
  - Desktop release workflow added (.github/workflows/release-desktop.yml) to build macOS/Windows/Linux artifacts, upload SHA256 checksums, and attach optional SBOM.
  - Telemetry: Added startup performance breadcrumb, FlutterError.onError capture, and runZonedGuarded in main.dart for crash telemetry on desktop.
  - Docs: Expanded docs/RELEASE_CHECKLIST.md with packaging/signing, CI artifacts, smoke checks, updater strategy, distribution, and performance sanity.
  - Version bump in pubspec.yaml.
- Rollback:
  - Revert the workflow and main.dart changes.
  - Restore previous pubspec.yaml version if needed.


## 1.2.0 - 2025-09-30

### Added
- Production Readiness Dashboard (`docs/PRODUCTION_READINESS_DASHBOARD.md`) summarizing status, checklists, KPIs, alerts, and go-live criteria.
- Monitoring & Observability guide (`docs/monitoring/MONITORING_SETUP.md`) with logging, metrics, alerting, dashboards, and uptime monitoring examples.
- GitHub Actions release workflow (`.github/workflows/release.yml`) to auto-create GitHub Releases on tag push (v*).

### Changed
- Documentation sweep to align with production readiness (deployment guides, quick reference, master guide).

### Fixed
- Minor typos across deployment docs.

