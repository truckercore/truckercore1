# Billing Reconciliation – Activation, Monitoring, Rollback, Hygiene

## Summary
Reconcilation compares entitled seats (billing_entitlements) vs provisioned seats (billing_seats) per tenant and alerts on drift. This runbook explains how to activate the job, monitor it, roll back safely, and apply manual fixes.

## Monitoring
- Ops Dashboard: /admin/ops → Billing sections:
  - Active Seats by Org
  - Entitled vs Provisioned (rows with drift highlighted)
  - Drift Daily (30d)
- Metrics: metrics_events with kind `billing_recon` captures driftCount and duration.
- Alerts: alerts emitted via `billing_recon_drift` through alert_outbox (dedup/escalation handled by existing pipeline).
- Heartbeat: cron_heartbeats key `billing_recon` should update hourly.

## Activation
1) Ensure tables exist (optional; views are resilient if absent):
   - public.billing_entitlements(org_id uuid, entitled_seats int)
   - public.billing_seats(org_id uuid, active_seats int)
2) Set repo secrets for CI if you want metrics/alerts:
   - SUPABASE_FUNCTIONS_URL (optional for notify)
   - SUPABASE_SERVICE_ROLE_KEY
   - SUPABASE_DB_URL (for heartbeat/SQL checks)
3) The CI workflow `.github/workflows/billing_reconciliation.yml` runs hourly with jitter.
4) Manual run:
   - `node scripts/recon/reconcile_billing.mjs` or provide JSON via `RECON_INPUT=path.json`.

## Rollback
- Disable the workflow in GitHub Actions (Billing Reconciliation) or set environment to skip (e.g., remove secrets).
- Mute alerts temporarily via /api/ops/mute (60m) or adjust alert_routes for `billing_recon_drift`.
- Validate: Ops dashboard no longer shows new drifts; heartbeats stop updating for `billing_recon`.

## Hygiene (Manual Fix Steps)
1) Identify drift rows from the Ops dashboard or by querying `billing_entitled_vs_provisioned`.
2) Fix entitlements or provisioned counts:
   - Increase entitlements to cover legitimate growth, or
   - Deprovision excess seats to meet current entitlements.
3) Re-run reconciliation job (workflow dispatch) to confirm driftCount returns to 0.
4) Retention:
   - Billing logs/reports purge via `public.purge_billing_logs(180)` (see 1011_billing_retention.sql). Adjust days per policy.

## Thresholds
- Any drift > 0 triggers a warning-level alert.
- Consider adding per-tenant thresholds once baseline is established (not included in this stub).

## Notes
- The stub job is instrumented but does not mutate billing data.
- RLS: CI checks verify RLS is enabled for billing tables if present.
