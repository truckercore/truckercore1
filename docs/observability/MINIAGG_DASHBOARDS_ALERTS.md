# PR5/PR6 — Mini‑Aggregations Dashboards and Alerts

This document describes the new streaming mini‑aggregations and recommended dashboards/alerts to satisfy PR5/PR6.

## Streaming mini‑aggregations (PR5)

Implemented in scripts/server/ingest_tracking.mjs:
- Rolling per‑truck/day aggregates maintained in memory:
  - km_traveled (sum of segment distances)
  - driving_minutes (inst. speed ≥ 2.0 m/s)
  - idle_minutes (otherwise)
- Updated on each accepted GPS point using the previous point for that device.
- Low‑latency read path: GET /miniagg?device_id=...&day=YYYY-MM-DD
  - Returns { device_id, day, km_traveled, driving_minutes, idle_minutes, updated_at }
- Freshness metrics: /metrics includes
  - miniagg_freshness_seconds{device_id,day}
  - miniagg_freshness_seconds_max (max across device/day)

Notes
- Late points (higher seq but older timestamp) are ignored for accumulation to avoid double‑counting; real‑time stream remains stable.
- Threshold can be tuned via MINIAGG_DRIVING_THRESHOLD_MPS (default 2.0 m/s).

## Suggested dashboards (PR6)

Panels to add alongside existing ingest/geofence metrics:
1) Mini‑agg freshness
   - Series: miniagg_freshness_seconds_max (global) and per device/day labels.
   - Alert: freshness > 300s (5 min) for any key sustained 5 minutes.
2) Per‑device/day aggregates (optional QA/ops view)
   - Pull from GET /miniagg for recent devices to spot check km/min accumulation.
3) Existing ingest/geofence panels (already documented)
   - events/min, eval latency p95, candidate counts, dwell_suppressed_total,
     meters/day (enter/exit), limit blocks, cache sizes.

## Alerts (PR6)

- Eval p95 > 150 ms (existing): derived from geofence_eval_latency_ms_* buckets.
- Mini‑agg freshness breach: miniagg_freshness_seconds_max > 300 for 5 minutes.
- Sustained high candidate counts, suppression anomalies, limit‑block spikes (as in existing docs).

## Ops runbook (overview)
- Staging soak: replay synthetic routes; expect freshness near zero while stream active.
- Pilot: enable for a small org cohort; keep kill‑switch for geofencing.
- Rollback: mini‑aggregations are in‑memory only; disable by not scraping/using /miniagg if needed.
