#!/usr/bin/env bash
set -euo pipefail

DB="${DATABASE_URL:-${READONLY_DATABASE_URL:-}}"
[ -n "${DB}" ] || { echo "::error ::DATABASE_URL or READONLY_DATABASE_URL required"; exit 1; }

psql "$DB" -f docs/sql/billing_extras.sql
psql "$DB" -f docs/sql/billing_webhook_audit.sql
psql "$DB" -f docs/sql/billing_health.sql

echo "Billing extras SQL applied." 