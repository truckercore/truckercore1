#!/usr/bin/env bash
set -euo pipefail

DB="${READONLY_DATABASE_URL:?READONLY_DATABASE_URL required}"

# Ensure MV exists and can refresh concurrently
psql "$DB" -v ON_ERROR_STOP=1 -c "refresh materialized view concurrently public.usage_monthly;" || {
  echo "::error ::Failed to refresh usage_monthly"; exit 1;
}

# Smoke the report function (pick any org present in usage_monthly)
psql "$DB" -v ON_ERROR_STOP=1 -c "select * from public.usage_report((select org_id from public.usage_monthly limit 1), current_date - 60, current_date) limit 1;" || {
  echo "::error ::usage_report RPC failed"; exit 1;
}

echo "Usage gates OK"