#!/usr/bin/env bash
set -euo pipefail
# Ingest one event
curl -fsS -X POST "$FUNC_URL/iot_ingest" \
  -H "authorization: $SERVICE_TOKEN" -H "content-type: application/json" \
  -d '{"device_id":"dev-1","location_id":"00000000-0000-0000-0000-000000000001","kind":"parking","payload":{"spaces_free":42}}' > /dev/null

# Optionally trigger aggregator if not scheduled
# curl -fsS "$FUNC_URL/parking-aggregate" > /dev/null

# Read aggregate
psql "$SUPABASE_DB_URL" -c "select location_id, occupancy, spaces_free, confidence from parking_state order by updated_at desc limit 5;"
echo "✅ parking smoke passed"
