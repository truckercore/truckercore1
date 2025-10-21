# Geofence Detection — Staging Soak, Pilot Rollout, and Rollback Runbook

Last updated: 2025-09-18

Feature scope: PR1 geofencing (circles) behind flags in scripts/server/ingest_tracking.mjs with hysteresis and state cache.

Flags and env knobs
- FLAG_GEOFENCE: enable geofencing logic (default: false)
- FLAG_GEOFENCE_KILL: kill‑switch to bypass detection early even when enabled (default: false)
- GEOF_EPSILON_M: hysteresis epsilon for exit boundary in meters (default: 20)
- GEOF_CANDIDATE_RADIUS_KM: max center distance for candidate search (default: 5)
- GEOF_MAX_CANDIDATES: hard cap on evaluated candidates per point (default: 50)
- IDEM_TTL_SECONDS, MAX_IDEM_CACHE: idempotency cache TTL/cap (default 600s/10000)
- DEVICE_STATE_TTL_SECONDS, MAX_DEVICES: per‑device state TTL/cap (default 24h/50000)
- GEOF_STATE_TTL_SECONDS, MAX_GEOFENCE_STATE: per (device,fence) state TTL/cap (default 24h/50000)
- GEOF_STATE_PERSIST_FILE, GEOF_STATE_PERSIST_INTERVAL_S: optional persistence of geofence state to reduce double‑emits across restarts

Staging soak (24–48h)
1) Enable flags in staging
   - FLAG_GEOFENCE=true
   - FLAG_GEOFENCE_KILL=false
   - Keep defaults: GEOF_EPSILON_M=20, GEOF_CANDIDATE_RADIUS_KM=5, GEOF_MAX_CANDIDATES=50
2) Run synthetic routes continuously (recommended cases):
   - Pass‑through: outside → inside → outside
   - Linger: outside → inside → several inside points
   - Boundary‑glide: oscillate within epsilon outside boundary (no thrash)
   - Re‑entry: outside → inside → outside (>r+ε) → inside
   See: docs/tests/PR1_GEOFENCE_TEST_MATRIX.md
3) Monitor /metrics (scrape every 15–60s)
   - events/min: geofence_enter_total, geofence_exit_total deltas
   - eval latency p95: geofence_eval_latency_ms_bucket/county (proxy p95 from buckets)
   - cache sizes: geofence_states_cached, geofence_event_idem_size, device_*_cache_size, idem_cache_size
   - ingest health: ingest_requests_total, ingest_accepted, dropped_* counters
4) Acceptance during soak
   - No boundary thrash in logs (alternating enter/exit without real movement)
   - Eval p95 < 10ms per point with ≤10 candidates
   - Cache sizes stable (no unbounded growth)
   - No duplicate transitions for identical second timestamps

Rollback triggers (act immediately)
- Eval p95 > 50ms sustained 5+ minutes
- Error rate > 1% (HTTP 5xx or handler errors visible in logs)
- Events/min spikes 10× above expected baseline without correlated movement
- Cache sizes exceed configured caps or grow monotonically through soak

Rollback actions
1) Immediate soft disable: set FLAG_GEOFENCE_KILL=true (no restart required if read per request; otherwise hot‑reload/restart service).
2) Full disable: set FLAG_GEOFENCE=false and restart service.
3) Reduce load: lower GEOF_MAX_CANDIDATES (e.g., 20) and GEOF_CANDIDATE_RADIUS_KM (e.g., 3) and retry.
4) Increase hysteresis: raise GEOF_EPSILON_M (e.g., 25m) if boundary thrash observed.
5) If duplicate emits after restart: set GEOF_STATE_PERSIST_FILE to enable persistence and rerun. Idempotency TTL protects duplicates temporarily.

Production pilot
- Pilot scope: 1–2 orgs (whitelist by org_id in geofencesByOrg cache or upstream DB filter)
- Flags: FLAG_GEOFENCE=true, FLAG_GEOFENCE_KILL=false
- Monitors: same dashboards as staging; define alert thresholds (see Observability doc) and page on spikes.
- Rollback: same triggers and actions; keep kill‑switch handy during pilot.

Runbook verification checklist
- [ ] Flags set as intended; documented in deployment config
- [ ] Synthetic generator running; scenarios validated
- [ ] Dashboards show events/min, eval latency, and cache sizes
- [ ] Alerts wired for p95 latency, error rate, and cache growth
- [ ] Rollback tested (toggle kill‑switch) and documented

References
- Implementation: scripts/server/ingest_tracking.mjs
- Tests: tests/server/geofence_pr1.test.js
- PR2 test matrix (polygons/dwell/candidate indexing): docs/tests/PR2_GEOFENCE_POLYGON_TEST_MATRIX.md
- Observability setup: docs/observability/GEOFENCE_DASHBOARDS_ALERTS.md
