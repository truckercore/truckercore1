#!/usr/bin/env bash
set -euo pipefail
: "${FUNC_URL:?}" : "${TEST_JWT:?}"
body='{"driver_id":"00000000-0000-0000-0000-000000000000","session_id":"00000000-0000-0000-0000-000000000000","bbox":"-122.6,37.3,-121.9,37.9"}'
code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$FUNC_URL/eld/predict_hos" -H "authorization: $TEST_JWT" -H "content-type: application/json" -d "$body")
[ "$code" = "200" ] || { echo "❌ predictive_hos $code"; exit 3; }
echo "✅ predictive HOS probe"
