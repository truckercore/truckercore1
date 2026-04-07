#!/usr/bin/env bash
set -euo pipefail
: "${FUNC_URL:?}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "$DIR/../../scripts/lib_probe.sh"
N="${N:-20}"; BBOX="${BBOX:--93.8,41.5,-93.4,41.8}"
seq 1 "$N" | while read -r _; do
  t0=$(date +%s%3N)
  curl -fsS "$FUNC_URL/poi/parking?bbox=$BBOX" > /dev/null
  echo $(( $(date +%s%3N) - t0 ))
done | compute_p95 "pois" "parking_bbox" >/dev/null
P95=$(sed -n 's/.*"p95_ms":\([0-9]*\).*/\1/p' "$REPORT_DIR/pois_parking_bbox_probe.json")
test -n "$P95" && [ "$P95" -le "${POIS_P95_MS:-800}" ] || { echo "❌ p95=${P95}ms > SLO"; exit 4; }
echo "✅ pois probe SLO ok (p95=${P95}ms)"
