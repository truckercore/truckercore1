#!/usr/bin/env bash
set -euo pipefail

DB="${DATABASE_URL:-${READONLY_DATABASE_URL:-}}"
[ -n "${DB}" ] || { echo "::error ::DATABASE_URL or READONLY_DATABASE_URL required"; exit 1; }

psql "$DB" -f docs/sql/feature_catalog_pack.sql
psql "$DB" -f docs/sql/feature_catalog_extras.sql
psql "$DB" -f docs/sql/feature_catalog_admin.sql

echo "Feature catalog SQL applied (pack + extras + admin)." 
