# Effective Flags — What to Toggle and Where

This repo uses environment/flag toggles primarily in the ingest server and the app runtime. Use staging/prod specific envs.

Ingest server (scripts/server/ingest_tracking.mjs)
- FLAG_GEOFENCE: Enable geofencing detection (default false)
- FLAG_GEOFENCE_KILL: Kill‑switch to bypass detection even if enabled
- GEOF_EPSILON_M: Hysteresis epsilon (meters)
- GEOF_CANDIDATE_RADIUS_KM: Candidate search radius (km)
- GEOF_MAX_CANDIDATES: Max candidates evaluated per point
- DWELL_SECONDS / ORG_SETTINGS_TTL_SECONDS: Dwell gating + hot‑reload TTL
- PLAN_LIMIT_GEOFENCE_EVENTS_PER_DAY: Default daily cap (PR3)

App (Flutter)
- SENTRY_DSN (telemetry on/off)
- RELEASE_CHANNEL (env tagging)
- SUPABASE_URL / SUPABASE_ANON_KEY (backend wiring)

Web/Workers
- FLAG_WEBHOOK_WORKER (enable worker)

How to toggle (recommended)
- Staging: Set environment variables in the process manager or .env for the staging instance(s) and restart if required.
- Production: Prefer infra‑managed secret/vars. Use the kill‑switch for immediate bypass.

Scripts
- npm run rollout:flags -- --env stage --enable geofence
  - Prints current recommended env exports and curl commands for a quick toggle (no remote write). Apply via your infra tool.
