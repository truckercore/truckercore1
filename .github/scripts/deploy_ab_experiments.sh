#!/usr/bin/env bash
set -euo pipefail

DB="${DATABASE_URL:-${READONLY_DATABASE_URL:-}}"
[ -n "${DB}" ] || { echo "::error ::DATABASE_URL or READONLY_DATABASE_URL required"; exit 1; }

psql "$DB" -f docs/sql/ab_experiments.sql
psql "$DB" -f docs/sql/ab_admin.sql

echo "AB experiments SQL applied (including admin RPCs)." 
