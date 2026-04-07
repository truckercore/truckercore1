#!/usr/bin/env bash
set -euo pipefail

# Find SECURITY DEFINER functions that don't set search_path=public explicitly on the same line
BAD_SD=$(grep -Rni --include='*.sql' -E 'create\s+or\s+replace\s+function\b.*\bsecurity\s+definer\b(?!.*set\s+search_path\s*=\s*public)' docs/sql || true)

# List public tables without RLS enabled (requires DATABASE_URL)
NO_RLS=${NO_RLS:-}
if [ -n "${DATABASE_URL:-}" ]; then
  NO_RLS=$(psql "$DATABASE_URL" -Atc "select relname from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and relkind='r' and not relrowsecurity;" || true)
else
  echo "[warn] DATABASE_URL not set; skipping RLS live check"
fi

if [ -n "$BAD_SD" ]; then
  echo "SECURITY DEFINER without search_path=public:"
  echo "$BAD_SD"
  exit 1
fi

if [ -n "$NO_RLS" ]; then
  echo "Tables without RLS:"
  echo "$NO_RLS"
  exit 1
fi

echo "SQL guard passed."