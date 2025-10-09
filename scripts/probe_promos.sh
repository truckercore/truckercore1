#!/usr/bin/env bash
set -euo pipefail
N=${N:-20}; FAIL=0; TSTART=$(date +%s%3N)
for i in $(seq 1 $N); do
  t0=$(date +%s%3N)
  curl -fsS -X POST "$FUNC_URL/promotions-issue-qr" \
    -H "authorization: $TEST_JWT" -H "content-type: application/json" \
    -d '{"promo_id":"00000000-0000-0000-0000-00000000PRMO"}' > /dev/null || FAIL=$((FAIL+1))
  dt=$(( $(date +%s%3N) - t0 )); echo $dt
done | sort -n | awk -v fail=$FAIL -v n=$N '
  END { p95_line=int(0.95*NR); if(p95_line<1)p95_line=NR; print "p95_ms=" $p95_line;
        if (fail>0) { exit 2 }
        if ($p95_line>1500) { exit 3 } }'
echo "✅ promos probe SLO ok"
