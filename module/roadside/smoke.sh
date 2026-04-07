#!/usr/bin/env bash
set -euo pipefail
: "${FUNC_URL:?}"; : "${TEST_JWT:?}"
curl -fsS -X POST "$FUNC_URL/roadside-match" \
  -H "authorization: $TEST_JWT" -H "content-type: application/json" \
  -d '{"lat":41.6,"lng":-93.6,"service_type":"tire"}' | grep -q '"candidates"'
echo "✅ roadside smoke passed"
