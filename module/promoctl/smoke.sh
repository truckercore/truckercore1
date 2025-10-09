#!/usr/bin/env bash
set -euo pipefail
: "${FUNC_URL:?}" : "${ADMIN_PROMOTE_KEY:?}"
BASE="$FUNC_URL/ai_ct/promote_model_v2"
curl -fsS -X POST "$BASE" -H "x-admin-key: $ADMIN_PROMOTE_KEY" \
  -H "x-idempotency-key: smoke-$(uuidgen)" -H "content-type: application/json" \
  -d '{"model_key":"eta","action":"increase_canary","pct":10}' >/dev/null
echo "✅ promote_model_v2 smoke"
