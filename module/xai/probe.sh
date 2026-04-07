#!/usr/bin/env bash
set -euo pipefail
: "${FUNC_URL:?}" : "${TEST_JWT:?}" ; . "$(dirname "$0")/../../scripts/lib_probe.sh"
N="${N:-8}"

# Probe explain latency by first creating a prediction, then fetching explain
PRED_FN="$(./scripts/resolve_fn.sh ai_eta_predict)"
XAI_FN="$(./scripts/resolve_fn.sh xai_eta_explain)"
seq 1 $N | while read -r _; do
  t0=$(date +%s%3N)
  CID=$(curl -fsS -X POST "$FUNC_URL/$PRED_FN" \
    -H "Authorization: Bearer $TEST_JWT" -H "Content-Type: application/json" \
    -d '{"features":{"distance_km":50,"avg_speed_hist":60,"hour_of_day":18,"day_of_week":3}}' | jq -r .correlation_id)
  curl -fsS "$FUNC_URL/$XAI_FN?correlation_id=$CID" >/dev/null
  echo $(( $(date +%s%3N)-t0 ))
done | compute_p95 "xai" "eta_explain" >/dev/null

P95=$(sed -n 's/.*"p95_ms":\([0-9]*\).*/\1/p' "$REPORT_DIR/xai_eta_explain_probe.json")
[ -n "$P95" ] && [ "$P95" -le "${XAI_P95_MS:-1200}" ] || { echo "❌ xai p95=$P95"; exit 4; }
echo "✅ xai probe"
