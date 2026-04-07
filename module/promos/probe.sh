#!/usr/bin/env bash
set -euo pipefail
: "${FUNC_URL:?}"; : "${TEST_JWT:?}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "$DIR/../../scripts/lib_probe.sh"
N="${N:-20}"; PROMO_ID="${PROMO_ID:-00000000-0000-0000-0000-00000000PRMO}"

seq 1 $N | while read -r _; do
  t0=$(date +%s%3N)
  curl -fsS -X POST "$FUNC_URL/promotions-issue-qr" \
    -H "authorization: $TEST_JWT" -H "content-type: application/json" \
    -d "{\"promo_id\":\"$PROMO_ID\"}" > /dev/null
  echo $(( $(date +%s%3N) - t0 ))
done | compute_p95 "promos" "issue_qr" >/dev/null

P95=$(sed -n 's/.*"p95_ms":\([0-9]*\).*/\1/p' "$REPORT_DIR/promos_issue_qr_probe.json")
assert_slo "$P95" "${SLO_P95_MS:-1500}"
echo "promos probe ok"
