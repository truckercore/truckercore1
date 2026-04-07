#!/usr/bin/env bash
set -euo pipefail
: "${FUNC_URL:?}"; : "${TEST_JWT:?}"; : "${REPORT_DIR:=./reports}"
. "$(dirname "$0")/../../scripts/lib_probe.sh"
N="${N:-15}"
mkdir -p "$REPORT_DIR"
FN_PATH="$(./scripts/resolve_fn.sh ai_fraud_detect)"
seq 1 $N | while read -r _; do
  t0=$(date +%s%3N)
  curl -fsS -X POST "$FUNC_URL/$FN_PATH" \
    -H "Authorization: Bearer $TEST_JWT" -H "Content-Type: application/json" \
    -d '{"features":{"age_days":0,"repeat_ip":1,"amount_usd":4500}}' >/dev/null
  echo $(( $(date +%s%3N)-t0 ))
done | compute_p95 "ai-fraud" "detect" >/dev/null
P95=$(sed -n 's/.*"p95_ms":\([0-9]*\).*/\1/p' "$REPORT_DIR/ai-fraud_detect_probe.json")
[ -n "$P95" ] && [ "$P95" ] && [ "$P95" -le "${AI_FRAUD_P95_MS:-800}" ] || { echo "❌ ai-fraud p95=${P95}"; exit 4; }
echo "✅ ai-fraud probe"