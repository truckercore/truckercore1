#!/usr/bin/env bash
set -euo pipefail
: "${FUNC_URL:?}"; : "${TEST_JWT:?}"; : "${SERVICE_TOKEN:?}"
PROMO_ID="${PROMO_ID:-00000000-0000-0000-0000-00000000PRMO}"

ISSUE=$(curl -fsS -X POST "$FUNC_URL/promotions-issue-qr" \
  -H "authorization: $TEST_JWT" -H "content-type: application/json" \
  -d "{\"promo_id\":\"$PROMO_ID\"}")
TOKEN=$(echo "$ISSUE" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p'); test -n "$TOKEN"

REDEEM=$(curl -fsS -X POST "$FUNC_URL/promotions-redeem" \
  -H "authorization: $SERVICE_TOKEN" -H "content-type: application/json" \
  -d "{\"token\":\"$TOKEN\",\"cashier_id\":\"desk-1\",\"subtotal_cents\":500}")
echo "$REDEEM" | grep -q '"approved":true'
echo "promos smoke ok"
