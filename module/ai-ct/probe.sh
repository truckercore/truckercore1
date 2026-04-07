#!/usr/bin/env bash
set -euo pipefail
: "${FUNC_URL:?}" : "${TEST_JWT:?}" ; . "$(dirname "$0")/../../scripts/lib_probe.sh"
N="${N:-15}"

FN_PATH="$(./scripts/resolve_fn.sh ai_eta_predict)"
seq 1 $N | while read -r _; do
  t0=$(date +%s%3N)
  curl -fsS -X POST "$FUNC_URL/$FN_PATH" \
    -H "Authorization: Bearer $TEST_JWT" -H "Content-Type: application/json" \
    -d '{"features":{"distance_km":80,"avg_speed_hist":63,"hour_of_day":14,"day_of_week":4}}' >/dev/null
  echo $(( $(date +%s%3N)-t0 ))
done | compute_p95 "ai-ct" "eta" >/dev/null

P95=$(sed -n 's/.*"p95_ms":\([0-9]*\).*/\1/p' "$REPORT_DIR/ai-ct_eta_probe.json")
[ -n "$P95" ] && [ "$P95" -le "${AI_ETA_P95_MS:-1200}" ] || { echo "❌ p95=$P95"; exit 4; }
echo "✅ ai-ct probe"
