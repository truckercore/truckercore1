#!/usr/bin/env bash
set -euo pipefail

: "${READONLY_DATABASE_URL:?missing READONLY_DATABASE_URL}"

# Fail if any active Stripe prices lack a mapping row
# NOTE: This assumes your pipeline ensures active prices are represented in stripe_price_map.
MISSING=$(psql "$READONLY_DATABASE_URL" -Atc "select count(*) from stripe_price_map where price_id is null")
if [ "${MISSING}" -ne 0 ]; then
  echo "::error ::Unmapped Stripe prices detected (${MISSING})"
  exit 1
fi

# Simulate key statuses across mapped prices (read-only safety)
psql "$READONLY_DATABASE_URL" -c "select price_id, (billing_simulate(price_id,'active')).* from stripe_price_map"
