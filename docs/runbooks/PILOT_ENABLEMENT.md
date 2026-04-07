# Pilot Enablement Validation

Goal: Enable features for a small cohort and validate stability for 24–48 hours.

Steps
1) Cohort selection
- Define 1–2 orgs as pilot cohort. Ensure geofence configuration is present only for these orgs.

2) Enable flags
- Apply FLAG_GEOFENCE=true; FLAG_GEOFENCE_KILL=false to production ingest for pilot window.
- Optionally set conservative settings (GEOF_CANDIDATE_RADIUS_KM=3, GEOF_MAX_CANDIDATES=30).

3) Verify kill‑switch
- Toggle FLAG_GEOFENCE_KILL=true and confirm transitions stop, then back to false.

4) Monitoring (24–48h)
- Dashboards: events/min, eval latency p95, candidate counts, dwell_suppressed_total, meters/day, freshness.
- Telemetry: delivery success > 99%; error rate < 1%.

5) Go/No‑Go + rollback triggers
- Go if SLOs hold for 24–48h and no critical issues.
- Rollback immediately if: eval p95 > 150ms sustained 5m, freshness > 300s, error rate > 1%, limit‑block surges.

6) Evidence
- Capture with `npm run rollout:evidence -- --env prod --ticket <ticket>` and attach to release ticket.
