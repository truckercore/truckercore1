#!/usr/bin/env bash
set -euo pipefail

: "${READONLY_DATABASE_URL:?set READONLY_DATABASE_URL}"

FAIL=$(psql "$READONLY_DATABASE_URL" -Atc "select coalesce(sum((not ok)::int),0) from public.sso_canary_results where at > now() - interval '1 hour';")
if [ "$FAIL" -eq 0 ]; then
  echo "SSO canary OK"
else
  echo "Recent SSO canary failures: $FAIL"
  exit 1
fi
