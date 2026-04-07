# PR1 Geofencing (Circles) — Test Matrix

Scope: Behind-flag geofencing for circle fences with hysteresis and state cache, idempotent event upsert, and metrics.

Flags
- FLAG_GEOFENCE: enable/disable feature (default: false)
- GEOF_EPSILON_M: hysteresis epsilon in meters (default: 20)
- FLAG_GEOFENCE_KILL: kill-switch to bypass detection early (default: false)

Test cases
1) Pass-through
- Setup: 1 circle (r=100m) at (40.0,-80.0). Points cross from outside -> inside -> outside.
- Input: 3-4 ordered points with seq increasing.
- Expect: events [enter, exit] exactly once each; metrics geofence_enter_total and geofence_exit_total increase for org.

2) Linger inside
- Setup: same fence. Outside -> inside -> multiple inside points.
- Expect: single enter, no exit until a point beyond (r+epsilon).

3) Boundary glide (no thrash)
- Setup: start inside. Oscillate around boundary with distance <= r+epsilon.
- Expect: at most one transition (initial enter); no rapid alternation.

4) Re-entry
- Setup: outside -> inside -> outside (> r+epsilon) -> inside again.
- Expect: events [enter, exit, enter].

5) Idempotency on replays
- Setup: duplicate points within the same second for the transition moment.
- Expect: only one event emitted due to idempotent key (truck|fence|type|occurred_at_sec).

6) Kill-switch
- Setup: FLAG_GEOFENCE=true and FLAG_GEOFENCE_KILL=true.
- Expect: 0 transitions regardless of inputs.

Performance validation
- Batch 1k points with <=10 candidate fences: p95 eval latency <10ms per point (read from histogram buckets / coarse proxy via /metrics).

Observability
- /metrics includes:
  - geofence_enter_total{org_id}
  - geofence_exit_total{org_id}
  - geofence_eval_latency_ms_bucket{org_id,le}
  - geofence_eval_latency_ms_count{org_id}
  - geofence_states_cached (debug gauge)

How to run
- Locally: `npm test` (Jest picks up tests/server/geofence_pr1.test.js)
- Enable flag in tests via env or per-test helper; defaults set in test file.

Notes
- Circle distance uses Haversine; candidate prefilter uses bounding boxes with a small margin.
- Hysteresis: exit only when distance > r + epsilon.
- Dwell is off in PR1 and will be introduced in PR2 with thresholds.
