#!/usr/bin/env bash
set -euo pipefail

: "${READONLY_DATABASE_URL:?set READONLY_DATABASE_URL}"

MISSING=$(psql "$READONLY_DATABASE_URL" -Atc \
  "select table_name from public.v_audit_trigger_coverage where has_audit_trigger=false;")
if [ -n "$MISSING" ]; then
  echo -e "Missing audit triggers on:\n$MISSING"
  exit 1
fi

echo "Audit trigger coverage OK"
