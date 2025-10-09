#!/usr/bin/env bash
set -euo pipefail
N=${N:-15}; FAIL=0
for i in $(seq 1 $N); do
  t0=$(date +%s%3N)
  curl -fsS -X POST "$FUNC_URL/roadside-match" \
    -H "authorization: $TEST_JWT" -H "content-type: application/json" \
    -d '{"lat":41.6,"lng":-93.6,"service_type":"tow"}' > /dev/null || FAIL=$((FAIL+1))
  dt=$(( $(date +%s%3N) - t0 )); echo $dt
done | sort -n | awk -v fail=$FAIL '
  END { p95=int(0.95*NR); if(p95<1)p95=NR; print "p95_ms=" $p95; if (fail>0) exit 2; if ($p95>2000) exit 3 }'
echo "✅ roadside probe SLO ok"
