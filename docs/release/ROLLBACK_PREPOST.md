# Rollback Pre/Post Checks

This short checklist accompanies scripts/release/undo.sh and helps confirm safe rollback.

## Pre‑checks
- Ops Dashboard (/admin/ops) reachable and loads quickly.
- Edge health function (functions/healthz) returns ok: true or a list of non‑fatal failures.
- Environment variables present: GET /api/ops/envcheck → ok.

## Rollback (one command)
```
SUPABASE_DB_URL=postgres://... ./scripts/release/undo.sh <feature_flag_key>
```
- If a feature flag key is passed, it will be disabled.
- Inserts a 60‑minute maintenance window to mute alerts during rollback.

## Post‑checks
- SLO burn panels (slo_burn_1h and slo_burn_7d) return to green.
- Alerts backlog drains (ops_alerts_pending shows 0 pending).
- Edge gate pre‑checks pass (Edge Pre‑Check or Edge Deploy Gate workflows).

## Notes
- The script is idempotent and safe to run multiple times.
- You can remove the maintenance window early by deleting the row from public.maintenance_windows.
- For noisy alerts after rollback, keep the mute active until the pipeline drains, then remove it.
