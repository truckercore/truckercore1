#!/usr/bin/env bash
set -euo pipefail
: "${SUPABASE_DB_URL:?}"
psql "$SUPABASE_DB_URL" -c "explain analyze select * from tiles_speed_agg where z=8 and x=100 and y=50 order by window_start desc limit 1;"
echo "✅ tiles SQL gates executed"
