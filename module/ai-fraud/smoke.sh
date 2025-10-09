#!/usr/bin/env bash
set -euo pipefail
: "${FUNC_URL:?}"; : "${TEST_JWT:?}"
FN_PATH="$(./scripts/resolve_fn.sh ai_fraud_detect)"
curl -fsS -X POST "$FUNC_URL/$FN_PATH" \
  -H "Authorization: Bearer $TEST_JWT" -H "Content-Type: application/json" \
  -d '{"features":{"age_days":1,"repeat_ip":0,"amount_usd":1200}}' | grep -q '"risk"'
echo "✅ ai-fraud smoke"