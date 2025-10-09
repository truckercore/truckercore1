#!/usr/bin/env bash
set -euo pipefail
: "${FUNC_URL:?}"; : "${TEST_JWT:?}"
FN_PATH="$(./scripts/resolve_fn.sh ai_eta_predict)"
curl -fsS -X POST "$FUNC_URL/$FN_PATH" \
  -H "Authorization: Bearer $TEST_JWT" -H "Content-Type: application/json" \
  -d '{"features":{"distance_km":120,"avg_speed_hist":70,"hour_of_day":14,"day_of_week":2}}' | grep -q '"prediction"'
echo "✅ ai-eta smoke"