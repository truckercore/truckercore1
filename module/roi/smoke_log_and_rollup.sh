#!/usr/bin/env bash
set -euo pipefail
: "${FUNC_URL:?FUNC_URL required}"

org="00000000-0000-0000-0000-0000000000ab"

curl -fsS -X POST "$FUNC_URL/roi/log_fuel_savings" -H 'content-type: application/json' \
  -d "{\"org_id\":\"$org\",\"driver_id\":null,\"gallons\":100,\"paid_price_per_gal\":3.80,\"baseline_price_per_gal\":3.95}"

curl -fsS "$FUNC_URL/roi/cron.refresh" >/dev/null

resp="$(curl -fsS "$FUNC_URL/roi/export_rollup?org_id=$org")"
echo "$resp" | jq -e '.rows | length >= 1' >/dev/null
echo "✅ ROI log+rollup/export OK"
