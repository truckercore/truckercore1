#!/usr/bin/env bash
set -euo pipefail
DB="${READONLY_DATABASE_URL:?missing DB url}"

# (1) Ensure price map has rows for active prices
MISSING=$(psql "$DB" -Atc "select count(*) from public.stripe_price_map")
if [ "$MISSING" -eq 0 ]; then
  echo "::error ::stripe_price_map is empty"
  exit 1
fi

# (2) Webhook idempotency table exists
if ! psql "$DB" -c "\d public.stripe_events_dedup" >/dev/null 2>&1; then
  echo "::error ::Missing public.stripe_events_dedup"
  exit 1
fi

# (3) RLS sanity on billing_profiles
RLS=$(psql "$DB" -Atc "select relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='billing_profiles'")
if [ "$RLS" != "t" ]; then
  echo "::error ::billing_profiles RLS disabled"
  exit 1
fi

echo "Billing gates OK"
