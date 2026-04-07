# PR5 Streaming Mini‑Aggregations — Test Matrix

Scope: Validate rolling per‑truck/day metrics (km_traveled, driving_minutes, idle_minutes), freshness metric, and robustness to late/out‑of‑order points.

Environment
- Start ingest server: `node scripts/server/ingest_tracking.mjs`
- Metrics endpoint: `GET /metrics`
- Read endpoint: `GET /miniagg?device_id=<id>&day=YYYY-MM-DD` (low‑latency)

Flags/Settings
- MINIAGG_DRIVING_THRESHOLD_MPS (default 2.0 m/s)
- JITTER_METERS (default 10 m)
- JITTER_SECONDS (default 5 s)

Test cases
1) Stream vs batch reconcile (±1%)
- Input: 4–8 ordered points over ~60s with modest moves.
- Expect: `/miniagg` km_traveled within ±1–2% of batch Haversine sum; (driving_minutes + idle_minutes) ≈ total elapsed minutes.
- Freshness: `miniagg_freshness_seconds{...}` close to 0; `miniagg_freshness_seconds_max ≤ 120`.

2) Late/out‑of‑order point (higher seq, older ts)
- Input: Ingest 2 ordered points, then a third with an older timestamp but higher seq.
- Expect: Totals do not increase; negative dt is ignored; `/miniagg` remains stable.

3) Jitter suppression
- Input: Two points <5s apart and <10 m apart.
- Expect: Second point dropped (`ingest_dropped_jitter` increments); `/miniagg` distance unchanged.

4) Teleport/outlier guard
- Input: Two points 1s apart but several km distance.
- Expect: Outlier dropped (`ingest_dropped_teleport` increments); `/miniagg` unaffected.

5) Freshness under steady ingest
- Input: Feed a point every 10–30s for ~2 minutes.
- Expect: `miniagg_freshness_seconds_max` stays ≤ 120; per device/day freshness near 0 shortly after last point.

Metrics to check
- `miniagg_freshness_seconds{device_id,day}` and `miniagg_freshness_seconds_max`
- `ingest_dropped_jitter`, `ingest_dropped_teleport`

Notes
- Use UTC timestamps (`.toISOString()`); derive `day` from UTC for `/miniagg`.
- Client jitter/outlier filters should already suppress obvious noise; server rechecks provide guardrails.
