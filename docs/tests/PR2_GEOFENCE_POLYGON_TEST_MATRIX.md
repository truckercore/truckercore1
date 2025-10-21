# PR2 Geofencing — Polygon + Dwell + Candidate Indexing Test Matrix

Scope: Reviewer checklist to validate PR2 implementation (polygons, dwell, spatial pre-indexing) on the ingest pipeline with synthetic routes. Use FLAG_GEOFENCE=true; keep FLAG_GEOFENCE_KILL=false.

Environment
- Start ingest server: node scripts/server/ingest_tracking.mjs (or via test harness)
- Configure:
  - GEOF_EPSILON_M=20 (default)
  - GEOF_CANDIDATE_RADIUS_KM=5 (or per test)
  - GEOF_MAX_CANDIDATES=50
  - EVENT_IDEM_TTL_SECONDS=3600
  - DEVICE_STATE_TTL_SECONDS=86400
- Load test fences:
  - Circle: id=c1, center=(40.000, -80.000), radius=150m
  - Polygon: id=p1, square around (40.001,-80.001) with ~200m sides

Cases
1) Polygon pass-through (enter→exit once)
- Route: line crossing polygon p1 interior, ~300m long, ~10s cadence.
- Expect: events: enter(p1) once, exit(p1) once. No duplicate enter/exit.
- Timing: events emitted at first interior point (enter) and first exterior point beyond hysteresis+ε (exit). Eval p95 < 10ms with ≤10 candidates.

2) Polygon boundary glide (no thrash)
- Route: path that skims along polygon edge within ±10m noise.
- Expect: either no events or a single enter if dwell (off) is disabled; no rapid enter/exit pairs (thrash). Hysteresis prevents flip-flop.

3) Polygon fast in/out jitter
- Route: two points: just inside then just outside within 2s.
- Expect: With dwell disabled, a single enter or enter+exit depending on ε; with dwell=5s, no events due to insufficient dwell.

4) Circle linger (dwell acceptance)
- Route: enter circle c1, remain inside for dwell=8s, then exit.
- Config: dwell_seconds=5.
- Expect: enter(c1) emitted at t≈5s (first point meeting dwell), exit emitted after leaving radius+ε.

5) Re-entry after exit
- Route: enter → exit → re-enter polygon p1 with 30s gap.
- Expect: enter, exit, enter again. Idempotent replays of the same batches must not duplicate events.

6) Candidate indexing guard
- Setup: 5km grid of 100+ fences; route passes near 3 of them.
- Config: GEOF_CANDIDATE_RADIUS_KM=3, GEOF_MAX_CANDIDATES=10.
- Expect: per point, ≤10 candidates evaluated; eval p95 stays under target.

7) Idempotency + ordering under out-of-order batches
- Send the same points twice and then a late batch with older timestamps.
- Expect: single set of enter/exit events; late points do not generate duplicates.

8) TTL/eviction sanity
- Configure short TTLs (EVENT_IDEM_TTL_SECONDS=5, DEVICE_STATE_TTL_SECONDS=5) and feed then wait.
- Expect: caches shrink (metrics: *_size decrease) after TTL; no memory growth across cycles.

Metrics to track
- geofence_enter_total/exit_total per org
- geofence_eval_latency_ms_bucket + *_count
- geofence_states_cached, geofence_event_idem_size, idem_cache_size, device_*_cache_size

Notes
- Use UTC seconds for timestamps; tolerate ±1–2s skew.
- Ensure reads/writes scoped by org_id in production integrations.
- Privacy: keep synthetic routes anonymous; do not include PII in logs.
