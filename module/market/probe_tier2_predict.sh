set -euo pipefail
: "${FUNC_URL:?}" "${ORG_ID:?}"
resp=$(curl -fsS -X POST "$FUNC_URL/market/predict.tier2" -H 'content-type: application/json' \
  -d "{\"org_id\":\"$ORG_ID\",\"lane_from\":\"DAL,TX\",\"lane_to\":\"LAX,CA\",\"equipment\":\"dry\"}")
echo "$resp" | jq -e '.rationale and .prediction_usd' >/dev/null || { echo "❌ Tier2 fail"; exit 4; }
echo "✅ Tier2 OK"
