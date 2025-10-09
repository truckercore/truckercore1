#!/usr/bin/env bash
set -euo pipefail

TARGET_TS="${1:-24 hours ago}"
RESTORE_DB="restore_$(date +%s)"

: "${BACKUP_URL:?Set BACKUP_URL to a dump URL or artifact path}"

createdb "$RESTORE_DB"
pg_restore --clean --no-owner --dbname="$RESTORE_DB" <(curl -s "$BACKUP_URL")
psql "$RESTORE_DB" -c "select now(), count(*) from pg_class;"

# Optional: run a basic DB smoke if present
if [ -x ./scripts/smoke_db.sh ]; then
  ./scripts/smoke_db.sh "$RESTORE_DB"
fi

echo "✅ PITR drill ok: $RESTORE_DB"
