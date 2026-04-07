#!/usr/bin/env bash
set -euo pipefail
: "${SUPABASE_DB_URL:?}"
psql "$SUPABASE_DB_URL" -c "select count(*) from poi_state;" >/dev/null
psql "$SUPABASE_DB_URL" -c "\di+ idx_pois_geom" | grep -q idx_pois_geom
echo "✅ pois SQL gates executed"
