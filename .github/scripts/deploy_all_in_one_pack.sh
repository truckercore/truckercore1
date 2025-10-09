#!/usr/bin/env bash
set -euo pipefail

DB="${DATABASE_URL:-${READONLY_DATABASE_URL:-}}"
[ -n "${DB}" ] || { echo "::error ::DATABASE_URL or READONLY_DATABASE_URL required"; exit 1; }

# Apply the all-in-one logistics SQL pack
psql "$DB" -f docs/sql/all_in_one_logistics_pack.sql

echo "All-in-one logistics SQL applied."