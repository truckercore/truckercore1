# GPS Hardening Backlog (P0–P2)

This document tracks the immediate backlog to ship a Driver Tracking MVP and harden the ingestion pipeline.

## MVP scope
- Background GPS with variable sampling:
  - Driving: 10–30s cadence
  - Idle: 2–5 min cadence
- Offline buffer and forward on reconnect
- Activity detection (basic): speed threshold + optional Activity API hints
- Simple driver UI: Start/Pause/Resume controls; HOS glance; current-trip card with upcoming stop (placeholder)

Client library: `lib/features/tracking/tracking_service.dart` (mock-first). Uploads to a configurable HTTP endpoint `/ingest` and falls back to a Supabase Edge Function if provided. Buffering is in-memory in MVP; persistent buffer via Hive is a near-term TODO.

## P0 (immediate)
- Unique key + indexes, dedup/out-of-order handling, retention, richer ingest metrics
  - Schema: `docs/supabase/gps_p0.sql` with `(device_id, seq)` unique constraint; `(device_id, ts)` index.
  - Server ingest (`scripts/server/ingest_tracking.mjs`):
    - Reject duplicates by `(device_id, seq)` idempotency key
    - Per-device last-seq memory to drop out-of-order (stale) points
    - Jitter filter: ignore points with <10 m movement within <5 s
    - Metrics: accepted/dropped, per-device counts, latency buckets
  - Tests: `tests/server/ingest_tracking.test.ts` simulate poor connectivity and day-boundary crossings

## P1
- Geofencing events + plan metering; configurable thresholds; streaming mini-aggregations
  - Emit `geofence_enter/exit` for stops (origin/destination) and configured zones
  - Per-org thresholds for jitter, min distance, min accuracy
  - Streaming aggregation to compute basic streaks (on-time arrivals) and idle hotspots (count per area)

## P2
- H3/PostGIS for heatmaps/proximity; backfill/replay tooling
  - Store H3 index per point (resolution 9–11) or PostGIS geography
  - Generate heatmaps; proximity queries for coaching/alerts
  - Backfill/replay tooling: re-ingest historical traces to rebuild aggregates

## Android specifics (optional, documented)
- Fused Location Provider in a Foreground Service + notification
- Activity Transitions API for motion gating (IN_VEHICLE, STILL, WALKING)
- WorkManager for upload retries (respect Doze/app-standby)
- Background location permission rationale and policy compliance

## Observability
- Prometheus metrics endpoint (server stub) under `/metrics`
- Client logs via `EventLogger` for state transitions and error paths

## Retention and privacy
- 90-day online retention (see SQL) with optional cold storage export
- Hash or pseudonymize device IDs for analytics; avoid PII in logs
