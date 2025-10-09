#!/usr/bin/env bash
set -euo pipefail

DB="${DATABASE_URL:-${READONLY_DATABASE_URL:-}}"
[ -n "${DB}" ] || { echo "::error ::DATABASE_URL or READONLY_DATABASE_URL required"; exit 1; }

psql "$DB" -f docs/sql/billing_profiles.sql
# Ensure idempotency helpers for webhook + mapping
psql "$DB" -f docs/sql/billing_webhook_idempotency.sql
psql "$DB" -f docs/sql/price_map.sql
# Apply billing runtime (fn_billing_apply, v_price_catalog, KPIs, drift)
psql "$DB" -f docs/sql/billing_apply_and_views.sql

echo "Billing profiles & runtime SQL applied." 