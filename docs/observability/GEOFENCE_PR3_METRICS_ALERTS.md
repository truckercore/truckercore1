# PR3 Metrics and Alerts — Geofence Plan Metering + Limits

This spec enumerates the metrics added for PR3 and suggested dashboard panels and alert thresholds.

## Metrics (Prometheus-style, exposed via GET /metrics)

Core series:
- geofence_events_meter{org_id,day} — Daily count of emitted geofence events (enter+exit) per org and UTC day.
- geofence_limit_block_total{org_id} — Counter of events blocked due to plan limits per org.
- geofence_enter_total{org_id} — Emitted enter transitions (post-cap) per org.
- geofence_exit_total{org_id} — Emitted exit transitions (post-cap) per org.

Supporting series (already present):
- geofence_eval_latency_ms_bucket{org_id,le}
- geofence_eval_latency_ms_count{org_id}
- geofence_eval_candidates{org_id}
- dwell_suppressed_total
- ingest_* and cache health metrics

## Suggested dashboards

1) Daily meters
- Panel: geofence_events_meter, grouped by org and day.
- Visualization: bar chart per day; top-N orgs stacked; optionally cumulative per day.

2) Limit blocks
- Panel: rate(geofence_limit_block_total[5m]) by org_id.
- Purpose: detect spikes in cap enforcement (possible misconfiguration or unexpected usage change).

3) Enters/Exits vs meters
- Panels: rate(geofence_enter_total[5m]) and rate(geofence_exit_total[5m]) vs meters.
- Purpose: ensure meters track emitted transitions and caps behave as expected.

4) Candidate counts & latency (existing)
- geofence_eval_candidates{org_id}
- geofence_eval_latency_ms_* histograms

## Alerts (initial thresholds)

- Limit block spike
  - Condition: rate(geofence_limit_block_total[10m]) by org_id > 0.1/s sustained 10m.
  - Action: page owning team; check plan caps and affected orgs.

- Candidate count sustained high (existing)
  - Condition: geofence_eval_candidates 95th percentile > configured cap for 10m.

- Eval latency p95 > 150 ms (existing)
  - See existing guide; keep thresholds consistent.

- Dwell suppression anomaly
  - Condition: dwell_suppressed_total increases while meters remain flat; may indicate dwell too high.

## Notes

- Meters are keyed by UTC day to avoid timezone ambiguity.
- Per‑org overrides are supported via settings cache; env PLAN_LIMIT_GEOFENCE_EVENTS_PER_DAY acts as default.
- Keep kill‑switch FLAG_GEOFENCE_KILL ready during rollout.
