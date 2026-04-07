#!/usr/bin/env bash
set -euo pipefail

DB="${DATABASE_URL:-${READONLY_DATABASE_URL:-}}"
[ -n "${DB}" ] || { echo "::error ::DATABASE_URL or READONLY_DATABASE_URL required"; exit 1; }

psql "$DB" -f docs/sql/global_safety_nits.sql

echo "Global safety nits SQL applied."