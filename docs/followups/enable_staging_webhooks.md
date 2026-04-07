# Follow-up: Enable Staging Webhooks Wiring (post-secrets)

Date: 2025-09-26
Owner: Webhooks On-Call (webhooks-oncall@example.com)
Environment: staging

Context
- Webhooks verifier, dashboards, and alerts are in place. We will wire staging once required secrets are provisioned.

Pre-requisites
- [ ] SUPABASE_SERVICE_ROLE (or SUPABASE_SERVICE_ROLE_KEY) configured in staging secrets store
- [ ] STAGING_WEBHOOK_SECRET_CURRENT set for test endpoint(s)
- [ ] Optional: STAGING_WEBHOOK_SECRET_NEXT + NEXT_EXPIRES_AT for rotation canary
- [ ] CHAOS_ENABLED=false and DRY_RUN=true for any CI hooks by default

Tasks
1) Edge/API wiring
- [ ] Expose a staging test endpoint (e.g., https://staging.example.com/webhooks/test)
- [ ] Ensure request path and method are stable and documented in docs/partners/webhooks_onboarding.md

2) Metrics and dashboards
- [ ] Confirm metrics ingestion for env=staging
- [ ] Import/verify dashboards/webhooks_overview.json (tagged env:staging)

3) Alerts
- [ ] Load alerts/slo_thresholds.yaml and alerts/anomaly/* with labels { env: staging, owner: webhooks-oncall }
- [ ] Route alerts to the on-call group (email/slack)

4) Partner simulation
- [ ] Use tooling/redteam/webhook_rt.mjs to validate cross-endpoint replay/downgrade protections (dry run ok)
- [ ] Send a signed test webhook using api/lib/webhook.ts signV2 helper

5) Chaos drills (optional, still dry-run)
- [ ] Run chaos/drills/* scripts with ENV=staging and CHAOS_ENABLED=false to validate logging paths

Acceptance
- [ ] Valid webhook verifies (result=ok) and appears on dashboard (env:staging)
- [ ] Invalid/replay tests show expected counters without noise in prod
- [ ] Alerts fire in staging when thresholds are temporarily breached (can simulate)

Notes
- Do not enable production wiring until staging is stable for ≥ 48h and SLOs hold.
