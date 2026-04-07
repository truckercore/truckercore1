# Parking Prediction – Activation & Rollback

## Summary
Parking Prediction provides short‑term forecasts of parking availability using recent state and historical trends. This runbook describes how to activate, monitor, and roll back the feature safely.

## Monitoring
- Ops Dashboard: /admin/ops → watch SLOs and alerts backlog.
- Health: supabase/functions/healthz should return ok:true.
- Metrics: metrics_events_daily (kinds like `parking_predict_req`, `parking_predict_err`).
- Latency: metrics_events_p95_24h for relevant kinds; alert thresholds via metrics_alert_thresholds.
- Cron heartbeats: cron_heartbeats entries for any scheduled predictors.

## Activation
1) Feature flag on:
   - SQL: `select public.set_feature_flag('parking_prediction', true, 'Enable parking predictions');`
2) Deploy predictors (Edge/Jobs) and ensure environment vars are set.
3) Schedule refreshes as needed (e.g., every 5–10 minutes for hot corridors) with safe caps/timeouts.
4) Confirm p95 latency and error rates remain within targets (see docs/SLOs.md).

## Rollback
- Disable via feature flag:
  - `select public.set_feature_flag('parking_prediction', false, 'Rollback');`
- Pause scheduled jobs (Supabase Scheduled Tasks or external cron).
- If alerts are noisy, insert a maintenance window: POST /api/ops/mute (60 min) or adjust alert_routes.
- Validate: Op dashboard SLOs recover; alerts backlog drains.

## Hygiene
- Secrets rotation tracked in public.secrets_metadata.
- Partition/state maintenance (if using large tables) and weekly vacuum/reindex jobs.
- Retention for metrics_events via purge_metrics_events(90).
