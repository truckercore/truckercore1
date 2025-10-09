#!/usr/bin/env bash
set -euo pipefail
: "${FUNC_URL:?}"; : "${TEST_JWT:?}"
FN_PATH="$(./scripts/resolve_fn.sh ai_match_score)"
curl -fsS -X POST "$FUNC_URL/$FN_PATH" \
  -H "Authorization: Bearer $TEST_JWT" -H "Content-Type: application/json" \
  -d '{"features":{"driver_score":0.7,"miles":450,"pickup_hour":10,"rate_per_mile":2.4}}' | grep -q '"score"'
echo "✅ ai-match smoke"