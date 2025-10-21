# Rollback / Kill‑Switch — One‑Pager

Purpose: Provide immediate, low‑risk steps to disable geofencing detection and restore baseline behavior.

Primary action (ingest server)
- Set FLAG_GEOFENCE_KILL=true (bypass detection) and reload service.
- If persistent disable is needed: set FLAG_GEOFENCE=false and reload.

Optional tuning under pressure
- Reduce GEOF_CANDIDATE_RADIUS_KM to 3.
- Reduce GEOF_MAX_CANDIDATES to 20.
- Increase GEOF_EPSILON_M to 25m to reduce boundary thrash.

Verification
- POST /ingest with a known route: geofence_transitions should be 0 with kill‑switch.
- GET /metrics: geofence_enter_total/exit_total stop increasing; eval latency decreases.

Command helper
- `npm run rollout:flags -- --env <stage|prod> --kill on` — prints recommended env toggles for copy‑paste.

Notes
- Keep the kill‑switch documented in on‑call runbooks.
- Revert tuning back to defaults once the incident is mitigated.
