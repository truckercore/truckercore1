#!/usr/bin/env bash
set -euo pipefail
PROMO_ID=00000000-0000-0000-0000-00000000PRMO

# Issue QR
ISSUE=$(curl -fsS -X POST "$FUNC_URL/promotions-issue-qr" \
  -H "authorization: $TEST_JWT" -H "content-type: application/json" \
  -d "{\"promo_id\":\"$PROMO_ID\"}")
TOKEN=$(echo "$ISSUE" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')
if [ -z "${TOKEN:-}" ]; then
  echo "Failed to extract token from ISSUE: $ISSUE" >&2
  exit 1
fi

# Redeem (simulate cashier)
REDEEM=$(curl -fsS -X POST "$FUNC_URL/promotions-redeem" \
  -H "authorization: $SERVICE_TOKEN" -H "content-type: application/json" \
  -d "{\"token\":\"$TOKEN\",\"cashier_id\":\"desk-1\",\"subtotal_cents\":500}")
echo "$REDEEM" | grep -q '"status":"approved"'
echo "✅ promos smoke passed"
