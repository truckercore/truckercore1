# Geofence Observability — Dashboards and Alerts

Last updated: 2025-09-18

This guide describes recommended dashboards and alert conditions for PR1 geofencing and ingest.

Metrics source
- Endpoint: GET /metrics (scripts/server/ingest_tracking.mjs)
- Format: plaintext metrics (Prometheus-style counters/gauges + histogram-like buckets)

Key metrics
- Ingest
  - ingest_requests_total
  - ingest_last_request_ms (latest request handling time)
  - ingest_accepted
  - ingest_dropped_dup, ingest_dropped_stale, ingest_dropped_jitter, ingest_dropped_teleport
  - idem_cache_size, device_seq_cache_size, device_point_cache_size
- Geofence
  - geofence_enter_total{org_id="..."}
  - geofence_exit_total{org_id="..."}
  - geofence_states_cached (debug gauge)
  - geofence_event_idem_size (debug gauge)
  - geofence_eval_latency_ms_bucket{org_id,le}
  - geofence_eval_latency_ms_count{org_id}

Dashboards (suggested panels)
1) Events per minute
   - Rate of enters and exits per org and total
   - PromQL example:
     - sum(rate(geofence_enter_total[5m])) by (org_id)
     - sum(rate(geofence_exit_total[5m])) by (org_id)
2) Eval latency (p50/p95)
   - Derive quantiles from buckets; for simplicity, track counts in each le and estimate p95.
   - If using Prometheus histograms, convert in a future iteration; for now, plot bucket cumulative series.
3) Cache sizes (health)
   - geofence_states_cached, geofence_event_idem_size, device_seq_cache_size, device_point_cache_size, idem_cache_size
   - Threshold annotations for caps.
4) Ingest health
   - ingest_last_request_ms (gauge/time-series)
   - dropped_* counters rates vs accepted rate.

Alerts (initial thresholds)
- Geofence eval p95 > 150 ms for 5m (per org)
  - Expression (approximate with bucket tail):
    - Use the highest "le" bucket value where count increases; if total count increases but last bucket rate grows sharply, trigger.
- Event error rate > 1%
  - If HTTP errors are exported separately, use that series; else infer from logs. (Future: export a counter.)
- Limit-block spikes (PR3)
  - geofence_limit_block_total rate > threshold (to be added in PR3).
- Cache size threshold
  - geofence_states_cached > 0.9 * MAX_GEOFENCE_STATE
  - geofence_event_idem_size > expected steady-state window

Runbooks
- See docs/runbooks/GEOFENCE_ROLLOUT_AND_ROLLBACK.md for staging soak acceptance criteria and rollback triggers.

Notes
- Buckets are emitted per org; some panels should aggregate across orgs and also show top-N orgs by volume.
- Once PR3 adds metering/limits, include meters/day/org and limit-block rates.
