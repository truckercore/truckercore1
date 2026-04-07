#!/usr/bin/env bash
set -euo pipefail
: "${FUNC_URL:?}"; : "${TEST_JWT:?}"
curl -fsS -X POST "$FUNC_URL/fleet-discounts-lookup" \
  -H "authorization: $TEST_JWT" -H "content-type: application/json" \
  -d '{"lat":41.6,"lng":-93.6,"fleet_org_id":"00000000-0000-0000-0000-0000000000F1"}' | grep -q '"discounts"'
echo "✅ discounts smoke passed"
