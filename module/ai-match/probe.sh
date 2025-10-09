#!/usr/bin/env bash
set -euo pipefail
: "${FUNC_URL:?}"; : "${TEST_JWT:?}"; : "${REPORT_DIR:=./reports}"
. "$(dirname "$0")/../../scripts/lib_probe.sh"
N="${N:-20}"
mkdir -p "$REPORT_DIR"
FN_PATH="$(./scripts/resolve_fn.sh ai_match_score)"
seq 1 $N | while read -r _; do
  t0=$(date +%s%3N)
  curl -fsS -X POST "$FUNC_URL/$FN_PATH" \
    -H "Authorization: Bearer $TEST_JWT" -H "Content-Type: application/json" \
    -d '{"features":{"driver_score":0.6,"miles":300,"pickup_hour":15,"rate_per_mile":2.1}}' >/dev/null
  echo $(( $(date +%s%3N)-t0 ))
done | compute_p95 "ai-match" "score" >/dev/null
P95=$(sed -n 's/.*"p95_ms":\([0-9]*\).*/\1/p' "$REPORT_DIR/ai-match_score_probe.json")
[ -n "$P95" ] && [ "$P95" -le "${AI_MATCH_P95_MS:-900}" ] || { echo "❌ ai-match p95=${P95}"; exit 4; }
echo "✅ ai-match probe"