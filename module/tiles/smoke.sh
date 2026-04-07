#!/usr/bin/env bash
set -euo pipefail
: "${SUPABASE_DB_URL:?}"
psql "$SUPABASE_DB_URL" -c "\d tiles_speed_agg" >/dev/null
psql "$SUPABASE_DB_URL" -c "select count(*) from tiles_speed_agg;" >/dev/null
echo "✅ tiles smoke passed"
