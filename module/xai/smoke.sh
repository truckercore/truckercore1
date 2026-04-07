#!/usr/bin/env bash
set -euo pipefail
: "${FUNC_URL:?}" : "${TEST_JWT:?}"

PRED_FN="$(./scripts/resolve_fn.sh ai_eta_predict)"
CID=$(curl -fsS -X POST "$FUNC_URL/$PRED_FN" \
  -H "Authorization: Bearer $TEST_JWT" -H "Content-Type: application/json" \
  -d '{"features":{"distance_km":40,"avg_speed_hist":55,"hour_of_day":20,"day_of_week":6}}' | jq -r .correlation_id)

XAI_FN="$(./scripts/resolve_fn.sh xai_eta_explain)"
curl -fsS "$FUNC_URL/$XAI_FN?correlation_id=$CID" | grep -q '"features"'
echo "✅ xai smoke"
