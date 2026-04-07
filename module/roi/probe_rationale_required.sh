#!/usr/bin/env bash
set -euo pipefail
: "${FUNC_URL:?FUNC_URL required}"

body='{"driver_id":"00000000-0000-0000-0000-000000000000","session_id":"00000000-0000-0000-0000-000000000000","bbox":"-122.6,37.3,-121.9,37.9"}'
r=$(curl -fsS -X POST "$FUNC_URL/eld/predict_hos" -H 'content-type: application/json' -d "$body")
echo "$r" | jq -e '.rationale' >/dev/null || { echo "❌ rationale missing"; exit 3; }
echo "✅ AI rationale present"
