#!/usr/bin/env bash
# scripts/rollback_rehearsal.sh
# Automated rollback rehearsal for staging
set -euo pipefail

: "${STAGING_SUPABASE_URL:?STAGING_SUPABASE_URL is required (psql connection string)}"
: "${STAGING_SERVICE_KEY:?STAGING_SERVICE_KEY is required (service role or admin key)}"
: "${BACKUP_TS:?BACKUP_TS is required (e.g., 2025-09-15T02:00:00Z)}"

# Optional app URL for HTTP smokes
: "${STAGING_APP_URL:=}"

echo "[rehearsal] start $(date -Is)"

# 1) Spin up restore DB from BACKUP_TS (provider-specific; placeholder)
# Example (pseudo): supabase admin backup-restore --project $STAGING_PROJECT --timestamp $BACKUP_TS
# echo "[rehearsal] Restoring backup at ${BACKUP_TS} (placeholder)"

# 2) Run smoke SQL against restore
if ! command -v psql >/dev/null 2>&1; then
  echo "[rehearsal] psql not found on PATH; please install postgresql-client" >&2
  exit 1
fi

export PGPASSWORD="${PGPASSWORD:-}"
psql "${STAGING_SUPABASE_URL}" <<'SQL'
select now() as db_time;
select to_regclass('public.alerts_events') as alerts_table;
select count(*) from public.pois;
SQL

# 3) Flip staging read-only env to restored DB (placeholder)
# export STAGING_DB_URL=postgres://...

# 4) App smoke via curl (adjust endpoints)
if [ -n "${STAGING_APP_URL}" ]; then
  echo "[rehearsal] HTTP smokes against ${STAGING_APP_URL}"
  curl -fsS "${STAGING_APP_URL}/api/health" -H "x-svc-key: ${STAGING_SERVICE_KEY}" || {
    echo "[rehearsal] health check failed" >&2; exit 1; }
  curl -fsS "${STAGING_APP_URL}/api/state/parking?bbox=-125,24,-66,50&min_conf=0.4" -H "x-svc-key: ${STAGING_SERVICE_KEY}" >/dev/null || {
    echo "[rehearsal] state/parking check failed" >&2; exit 1; }
else
  echo "[rehearsal] STAGING_APP_URL not set; skipping HTTP smokes"
fi

echo "[rehearsal] success $(date -Is)"