# Module Runbook

Use this document as a starting point for each module. For a specific module, copy docs/runbooks/RUNBOOK_TEMPLATE.md here and fill in details.

Owner: <team> | Flag: <FEATURE_FLAG_KEY>

## Purpose
<scope, endpoints, tables>

## Pre-Checks
- Migrations idempotent and applied
- Rollback rehearsal passed (date: __)
- Feature flag OFF in prod
- Backups/PITR healthy

## Activation
1) scripts/run_gate.sh <module> full
2) Enable flag for canary orgs
3) Validate dashboards (error%, p95)

## Monitoring & Alerts
- SLOs: p95 target, error budget
- Alerts: thresholds, channels

## Rollback
- Disable feature flag
- Run rollback SQL (if needed)
- Restore snapshot if data corruption

## Hygiene
- VACUUM/ANALYZE cadence
- Index bloat watch
- Retention jobs
