#!/usr/bin/env bash
set -euo pipefail

: "${READONLY_DATABASE_URL:?set READONLY_DATABASE_URL}"
: "${FILTER:?set FILTER (SQL predicate for users table)}"

COUNT=$(psql "$READONLY_DATABASE_URL" -Atc "select public.preview_announcement_audience($$${FILTER}$$);")
# Prefer DB-configured threshold; fall back to env MAX_AUDIENCE or 10000
DB_MAX=$(psql "$READONLY_DATABASE_URL" -Atc "select coalesce((select num from public.v_gate_thresholds where key='announce.max_audience'), null);") || DB_MAX=""
if [[ -z "${DB_MAX}" || "${DB_MAX}" == "" ]]; then
  MAX=${MAX_AUDIENCE:-10000}
else
  MAX=${DB_MAX}
fi
if [ "$COUNT" -le "$MAX" ]; then
  echo "Audience OK: $COUNT <= $MAX"
else
  echo "Audience too large: $COUNT > $MAX (threshold source: ${DB_MAX:+db}${DB_MAX:+' '}${DB_MAX:+'v_gate_thresholds'}${DB_MAX:+'|'}${MAX_AUDIENCE:+env}${MAX_AUDIENCE:+' '}" \
    | sed 's/|$//' || true
  exit 1
fi
