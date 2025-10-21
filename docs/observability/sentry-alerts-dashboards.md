# Sentry Performance Alerts and Dashboard (Config-as-Code)

This repository includes scripts to configure Sentry performance alerts and a custom dashboard for TruckerCore. They are idempotent and safe to run repeatedly. Use DRY_RUN to preview changes before applying.

## Prerequisites

- Sentry organization slug: set `SENTRY_ORG`
- Sentry project slug: set `SENTRY_PROJECT`
- Sentry auth token with scopes: `org:read`, `org:write`, `project:read`, `project:write` → `SENTRY_AUTH_TOKEN`
- Optional: Slack or PagerDuty integrations installed in Sentry (scripts currently create alerts without integration-specific actions; you can add actions in the Sentry UI).

## What’s created

### Metric Alerts
1. Slow App Startup
   - Metric: `avg(transaction.duration)`
   - Filter: `transaction:"app.startup"`
   - Threshold: > 3000 ms
   - Frequency: 5 minutes
   - Action: none by default (add Slack/PagerDuty in Sentry UI)

2. Fleet Map Regression
   - Metric: `p95(transaction.duration)`
   - Filter: `transaction:"fleet_map.build"`
   - Threshold: > 2000 ms
   - Frequency: 10 minutes
   - Action: none by default

3. High Error Rate
   - Metric: `count()`
   - Filter: errors (dataset=events)
   - Threshold: > 100 events in 5 minutes
   - Action: none by default

4. Performance Degradation (placeholder)
   - Concept: `compare(avg(transaction.duration), 1h, 24h) > 20%`
   - Note: Sentry’s public API does not currently expose a first-class `compare()` condition for metric alerts; we create a placeholder alert using `avg(transaction.duration)` so you can refine it in the Sentry UI.

### Dashboard: "TruckerCore Performance"
Widgets:
- App Startup Trend: `avg(transaction.duration)` by release for `transaction:"app.startup"` (Line, last 7 days)
- Critical Path Performance: avg for `app.startup`, `dashboard.render`, `fleet_map.build`, `report.generate` (Bar, last 24 hours)
- Performance by Platform: `avg(transaction.duration)` by `os.name` (Table, last 24 hours)
- Slowest Transactions: top 10 by `p95(transaction.duration)` (Table, last 1 hour)
- CI vs Production Comparison: p50 for `app.startup` with a note to compare vs CI baseline (Line/Big number with description)

## Run commands

Preview (no changes):
```
DRY_RUN=1 SENTRY_AUTH_TOKEN=... SENTRY_ORG=truckercore SENTRY_PROJECT=<project-slug> \
  npm run obs:sentry:apply
```

Apply:
```
SENTRY_AUTH_TOKEN=... SENTRY_ORG=truckercore SENTRY_PROJECT=<project-slug> \
  npm run obs:sentry:apply
```

Individual:
```
# Alerts only
npm run obs:sentry:alerts

# Dashboard only
npm run obs:sentry:dashboard
```

## CI workflow (optional)
Create a repo `Actions secret` for `SENTRY_AUTH_TOKEN` and `Actions variables` for `SENTRY_ORG`, `SENTRY_PROJECT`. Then run via the provided workflow `.github/workflows/sentry-apply.yml` (added by this change). You can also execute it manually with `workflow_dispatch`.

## Slack/Discord Integration
- Install Slack integration in Sentry: Settings → Integrations → Slack
- Map project/alerts to channels:
  - #engineering-performance for performance alerts
  - #engineering-team for degradation announcements
- After integration, edit each alert in Sentry and add a Slack action (the script leaves actions empty if Slack isn’t configured).

If using Discord or other chat tools, consider Sentry’s webhook integration to a relay that posts to your chat.

## Tuning
- Thresholds can be adjusted directly in Sentry after creation.
- Use `NAME_PREFIX="[Staging]"` env to create a second, namespaced dashboard for staging.
- Use `SENTRY_BASE_URL` if your organization uses a specific Sentry region (defaults to https://sentry.io).

## Troubleshooting
- 403/401 errors: verify token scopes and org membership.
- Unknown API path: Sentry APIs may evolve. Re-run with DRY_RUN to capture payloads and adjust as needed.
- Slack actions missing: ensure Slack integration is installed in Sentry; then add actions in the alert rule UI.
