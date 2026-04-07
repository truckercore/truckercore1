set -euo pipefail
: "${FUNC_URL:?}" "${ORG_ID:?}"
code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$FUNC_URL/market/insurance.tier3" \
  -H 'content-type: application/json' -d "{\"org_id\":\"$ORG_ID\",\"lane_from\":\"DAL,TX\",\"lane_to\":\"LAX,CA\",\"equipment\":\"dry\"}")
[ "$code" -ge 200 ] && [ "$code" -lt 500 ] || { echo "❌ Tier3"; exit 5; }
echo "✅ Tier3 OK (coverage/guard path)"
