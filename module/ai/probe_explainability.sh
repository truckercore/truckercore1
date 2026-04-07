#!/usr/bin/env bash
set -euo pipefail
: "${FUNC_URL:?}" : "${TEST_JWT:?}"
body='{"driver_id":"00000000-0000-0000-0000-000000000000","session_id":"00000000-0000-0000-0000-000000000000","bbox":"-122.6,37.3,-121.9,37.9"}'
resp=$(curl -fsS -X POST "$FUNC_URL/eld/predict_hos" -H "authorization: $TEST_JWT" -H "content-type: application/json" -d "$body")
echo "$resp" | jq -e '.rationale' >/dev/null || { echo "❌ rationale missing"; exit 3; }
echo "✅ explainability present"
