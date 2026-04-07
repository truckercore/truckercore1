# Runbook: Schedulers, Parameters, and Incidents

This runbook covers enabling/disabling scheduled Edge Functions, tuning parameters via env toggles, and incident response steps for the POI fusion/forecasting pipeline.

Scope
- cron.aggregate_poi_states — aggregates POI reports into parking_state and weigh_station_state.
- cron.parking_forecast_rollup — builds rolling averages into parking_forecast.
- cron.speed_tiles_v1 — aggregates GPS speed tiles.
- parking.forecast.seed — on-demand backfill for missing forecasts.

Enable/Disable Schedulers
1) Supabase Dashboard → Edge Functions → Schedules.
2) Toggle the schedule for each function as needed.
3) For temporary pauses, prefer disabling schedules over redeploys.

Parameter Changes (env toggles)
Set under Edge Functions → Settings → Environment Variables, then redeploy or cold-start.
- DECAY_HALFLIFE_MIN (alias DECAY_HALF_LIFE_MIN)
- FUSION_WINDOW_MIN
- OPERATOR_WEIGHT
- CROWD_MIN_TRUST
- SPEED_WINDOW_MIN
- SPEED_TILE_ZOOM
- FORECAST_LOOKBACK_DAYS
See docs/config/toggles.md for defaults and ranges.

Operational Checks
- Freshness: query parking_state/weigh_station_state for max(last_update) and alert if stale > 30 minutes for active POIs.
- Forecast freshness: ensure parking_forecast.updated_at within last 24 hours.
- Endpoint SLOs: state.parking/state.weigh p95 < 200ms.

Dashboards & Alerts
- Dashboards: see observability/state_endpoints_dashboards.md (fusion success/min, state rows updated/min, forecast freshness, endpoint p95, 304 rate).
- Alerts:
  - Fusion failure > 3 runs (no success or processed_poi=0): page.
  - Stale state > 30 minutes for active POIs: warn.
  - Forecast job last success > 25h: warn.

Incident Steps
1) Diagnose
- Check recent logs for fusion.run events; confirm window_min and half_life_min values.
- Verify state endpoints are serving and logging.
2) Remediate
- If no recent reports: run parking.forecast.seed to prevent empty UI.
- Increase FUSION_WINDOW_MIN temporarily if reports are sporadic.
- Raise OPERATOR_WEIGHT if operator overrides should dominate.
- Lower DECAY_HALFLIFE_MIN to accelerate decay of stale crowd data.
3) Validate
- Confirm dashboards recover (processed_poi > 0, updates/min back to baseline).
- Verify UI shows state and forecasts.

Hot-tune fusion (runbook snippet)
- Change env(s) in Supabase → Edge Functions → Settings: DECAY_HALFLIFE_MIN / FUSION_WINDOW_MIN / OPERATOR_WEIGHT / CROWD_MIN_TRUST.
- Trigger a single fusion run by invoking the scheduled function endpoint manually (or wait for next cron):
  - curl -sS "$SUPABASE_URL/functions/v1/cron.aggregate_poi_states"
- Verify top 5 POIs for drift using state endpoints and audit logs.
- Revert promptly if drift > agreed threshold.

Seeding rerun (idempotent)
- Safe to re-run seed with optional limit and kinds:
  - curl -sS "$SUPABASE_URL/functions/v1/parking.forecast.seed?limit=5000&kinds=truck_stop,parking"
- To backfill with a custom time window in rollup, adjust FORECAST_LOOKBACK_DAYS and trigger cron.parking_forecast_rollup once.

Common Queries (SQL)
- Stale state (>30 min):
```
select count(*) from parking_state where last_update < now() - interval '30 minutes';
```
- Forecast freshness:
```
select count(*) from parking_forecast where updated_at < now() - interval '25 hours';
```
- Endpoint latency (if logged to analytics table or logs exporter):
```
-- depends on your logging sink; scrape 'event=endpoint' lines and aggregate p95
```

Change Management
- Record parameter changes in audit_log via a lightweight admin tool or manual note.
- Use feature toggles to stage risky changes off-hours; roll back quickly by restoring previous env values.
