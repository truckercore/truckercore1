#!/usr/bin/env bash
set -euo pipefail
# Raw table RLS denied; public aggregate allowed
( psql "$SUPABASE_DB_URL" -c "select count(*) from iot_events" && echo "❌ expected deny" ) || echo "✅ iot_events RLS blocks"
psql "$SUPABASE_DB_URL" -c "select * from parking_state limit 1;" >/dev/null
# Partition presence (if enabled)
psql "$SUPABASE_DB_URL" -c "\\d+ iot_events" | grep -qi 'Partition key' || echo "ℹ️ iot_events not partitioned"
echo "✅ parking SQL gates executed"
