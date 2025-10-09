#!/usr/bin/env bash
set -euo pipefail
: "${FUNC_URL:?}"; : "${TEST_JWT:?}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "$DIR/../../scripts/lib_probe.sh"
N="${N:-25}"
seq 1 "$N" | while read -r _; do
  t0=$(date +%s%3N)
  curl -fsS -X POST "$FUNC_URL/fleet-discounts-lookup" \
    -H "authorization: $TEST_JWT" -H "content-type: application/json" \
    -d '{"lat":41.6,"lng":-93.6,"fleet_org_id":"00000000-0000-0000-0000-0000000000F1"}' > /dev/null
  echo $(( $(date +%s%3N) - t0 ))
done | compute_p95 "discounts" "lookup" >/dev/null
P95=$(sed -n 's/.*"p95_ms":\([0-9]*\).*/\1/p' "$REPORT_DIR/discounts_lookup_probe.json")
[ -n "$P95" ] && [ "$P95" -le "${DISCOUNTS_P95_MS:-1200}" ] || { echo "❌ p95=${P95}ms"; exit 4; }
echo "✅ discounts probe SLO ok"
