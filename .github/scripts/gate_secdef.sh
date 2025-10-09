#!/usr/bin/env bash
set -euo pipefail

: "${READONLY_DATABASE_URL:?set READONLY_DATABASE_URL}"

MISS=$(psql "$READONLY_DATABASE_URL" -Atc \
  "select schema||'.'||function||'('||args||')' from public.v_security_definer_inventory where not has_pinned_search_path;")
if [ -n "$MISS" ]; then
  echo -e "SECURITY DEFINER without pinned search_path:\n$MISS"
  exit 1
fi

echo "SECURITY DEFINER inventory OK"
