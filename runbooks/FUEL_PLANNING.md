# Fuel Planning – Activation & Rollback

## Summary
Fuel Planning recommends optimal stops based on price, detours, and compliance. This runbook documents how to activate, monitor, and roll back the feature.

## Monitoring
- Ops Dashboard: /admin/ops → metrics and SLOs.
- Metrics: metrics_events_daily kinds like `fuel_plan_req`, `fuel_plan_calc_ms`, `fuel_plan_err`.
- Latency: metrics_events_p95_24h for fuel planning kinds; set thresholds in metrics_alert_thresholds.
- Alerts: alert_outbox via notify-alerts; dedupe/escalation configured.

## Activation
1) Feature flag on:
   - SQL: `select public.set_feature_flag('fuel_planning', true, 'Enable fuel planning');`
2) Ensure indexes for queries backing price lookups and route keysets (see docs/supabase/pagination_indexes.sql).
3) Schedule periodic price cache refresh (daily) with safe caps/timeouts.
4) Validate with canary flows; watch p95 and error rates.

## Rollback
- Disable via feature flag:
  - `select public.set_feature_flag('fuel_planning', false, 'Rollback');`
- Stop scheduled refresh jobs.
- Mute alerts temporarily via /api/ops/mute if noisy.
- Confirm recovery on Ops dashboard.

## Hygiene
- Rotate provider keys via secrets_metadata; alert_on_stale_secrets.
- Retain metrics_events for 90 days via purge_metrics_events(90).
- Weekly geo maintenance if spatial queries involved (see weekly_geo_maintenance()).
