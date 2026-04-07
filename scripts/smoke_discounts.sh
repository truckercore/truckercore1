#!/usr/bin/env bash
set -euo pipefail
RES=$(curl -fsS -X POST "$FUNC_URL/fleet-discounts-lookup" \
  -H "authorization: $TEST_JWT" -H "content-type: application/json" \
  -d '{"lat":41.6,"lng":-93.6,"fleet_org_id":"00000000-0000-0000-0000-0000000000F1"}')
echo "$RES" | grep -q '"fuel_cents"'
echo "✅ discounts smoke passed"
