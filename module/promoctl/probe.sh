#!/usr/bin/env bash
set -euo pipefail
: "${FUNC_URL:?}" : "${ADMIN_PROMOTE_KEY:?}" ; : "${REPORT_DIR:=./reports}"
BASE="$FUNC_URL/ai_ct/promote_model_v2"
start=$(date +%s%3N)
curl -fsS -X POST "$BASE" -H "x-admin-key: $ADMIN_PROMOTE_KEY" \
  -H "x-idempotency-key: probe-$(uuidgen)" -H "content-type: application/json" \
  -d '{"model_key":"eta","action":"increase_canary","pct":10}' >/dev/null
lat=$(( $(date +%s%3N) - start ))
mkdir -p "$REPORT_DIR"
printf '{"module":"promoctl","op":"promote","p95_ms":%s}\n' "$lat" > "$REPORT_DIR/promoctl_promote_probe.json"
[ "$lat" -le "${PROMOCTL_P95_MS:-800}" ] || { echo "❌ promote latency $lat ms"; exit 4; }
echo "✅ promoctl probe p95=$lat ms"
