#!/usr/bin/env bash
set -euo pipefail
LOC=00000000-0000-0000-0000-000000000001
curl -fsS -X POST "$FUNC_URL/iot_ingest" \
  -H "authorization: $SERVICE_TOKEN" -H "content-type: application/json" \
  -d "{\"device_id\":\"dev-probe\",\"location_id\":\"$LOC\",\"kind\":\"parking\",\"payload\":{\"spaces_free\":37}}" > /dev/null

deadline=$(( $(date +%s) + 60 ))
ok=0
while [ $(date +%s) -lt $deadline ]; do
  cnt=$(psql -At "$SUPABASE_DB_URL" -c "select 1 from parking_state where location_id='$LOC' and updated_at>now()-interval '90 seconds' limit 1;")
  if [ "$cnt" = "1" ]; then ok=1; break; fi
  sleep 3
done
test $ok -eq 1 && echo "✅ parking probe SLO ok" || { echo "❌ parking aggregate not visible within 60s"; exit 3; }
