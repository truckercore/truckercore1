#!/usr/bin/env bash
set -euo pipefail
: "${SUPABASE_DB_URL:?}"
LAG=$(psql -At "$SUPABASE_DB_URL" -c "select coalesce(extract(epoch from (now()-max(updated_at)))::int,999999) from tiles_speed_agg;")
test "$LAG" -le "${TILES_MAX_LAG_SEC:-180}" || { echo "❌ tile lag=${LAG}s > threshold"; exit 3; }
echo "✅ tiles freshness ok (${LAG}s)"
