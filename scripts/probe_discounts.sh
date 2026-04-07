#!/usr/bin/env bash
set -euo pipefail
N=${N:-25}; FAIL=0
for i in $(seq 1 $N); do
  t0=$(date +%s%3N)
  curl -fsS -X POST "$FUNC_URL/fleet-discounts-lookup" \
    -H "authorization: $TEST_JWT" -H "content-type: application/json" \
    -d '{"lat":41.6,"lng":-93.6,"fleet_org_id":"00000000-0000-0000-0000-0000000000F1"}' > /dev/null || FAIL=$((FAIL+1))
  dt=$(( $(date +%s%3N) - t0 )); echo $dt
done | sort -n | awk -v fail=$FAIL '
  END { p95=int(0.95*NR); if(p95<1)p95=NR; print "p95_ms=" $p95; if (fail>0) exit 2; if ($p95>1200) exit 3 }'
echo "✅ discounts probe SLO ok"
