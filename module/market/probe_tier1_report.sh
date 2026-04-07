set -euo pipefail
: "${FUNC_URL:?}" "${ORG_ID:?}"
resp=$(curl -fsS "$FUNC_URL/market/reports.tier1?org_id=$ORG_ID&from=DAL,TX&to=LAX,CA&equip=dry")
echo "$resp" | jq -e '.rows | all(.n >= 10)' >/dev/null || { echo "❌ k-anonymity fail"; exit 3; }
echo "✅ Tier1 OK"
