# Dry‑Run (Staging) — 60–90 Minutes

Preconditions
- Release branch cut; CI green; SRE on‑call present.
- Staging endpoints configured in config/rollout.json.

Steps
1) Toggle flags (staging)
- Command: `npm run rollout:flags -- --env stage --enable geofence`
- Apply printed env toggles to staging ingest server; reload service.

2) Warm endpoints
- Command: `npm run rollout:warm -- --env stage`
- Verifies /metrics, /miniagg, and web health endpoints respond within tolerances.

3) Smoke checks
- App/web smoke scripts (manual or CI). Confirm basic flows load without error.

4) Validate SLOs
- Command: `npm run rollout:health -- --env stage`
- PASS when:
  - freshness ≤ 120s
  - ingest eval p95 proxy < 10ms/pt
  - (if applicable) read p95 < 150ms proxy

5) Exercise rollback
- Command: `npm run rollout:flags -- --env stage --kill on`
- Confirm geofence transitions go to 0; then restore `--kill off`.

6) Capture evidence
- Command: `npm run rollout:evidence -- --env stage --ticket <JIRA-123>`
- Attach generated MD to the release ticket.
