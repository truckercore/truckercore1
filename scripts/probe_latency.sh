#!/usr/bin/env bash
set -euo pipefail
URL="${1:?usage: $0 <url>}"
SLA_MS="${2:-500}" # default 500ms

# Requires: k6, jq, bc installed
if ! command -v k6 >/dev/null 2>&1; then echo "k6 is required"; exit 2; fi
if ! command -v jq >/dev/null 2>&1; then echo "jq is required"; exit 2; fi
if ! command -v bc >/dev/null 2>&1; then echo "bc is required"; exit 2; fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

cat >"$tmpdir/loadtest.js" <<'EOF'
import http from 'k6/http';
import { sleep } from 'k6';
export const options = {
  vus: __ENV.VUS ? parseInt(__ENV.VUS) : 50,
  duration: __ENV.DURATION || '30s',
};
export default function () {
  const url = __ENV.TARGET_URL;
  const res = http.get(url);
  sleep(0.1);
}
EOF

export TARGET_URL="$URL"
k6 run --vus "${VUS:-50}" --duration "${DURATION:-30s}" --summary-export="$tmpdir/summary.json" "$tmpdir/loadtest.js" >/dev/null

p95=$(jq -r '.metrics.http_req_duration["p(95.00)"]' "$tmpdir/summary.json")
# p95 is in ms
if (( $(echo "$p95 > $SLA_MS" | bc -l) )); then
  echo "❌ p95 latency exceeded SLA: ${p95} ms (SLA ${SLA_MS} ms)"
  exit 1
else
  echo "✅ p95 latency: ${p95} ms within SLA ${SLA_MS} ms"
fi
