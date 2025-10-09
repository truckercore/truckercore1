#!/usr/bin/env bash
set -euo pipefail

MODE=${1:-remote}
PROJECT_REF=${PROJECT:-<YOUR_PROJECT_REF>}
SUPABASE_URL_REMOTE="https://${PROJECT_REF}.supabase.co"
SUPABASE_URL_LOCAL="http://127.0.0.1:54321"

if [[ "$MODE" == "local" ]]; then
  BASE="$SUPABASE_URL_LOCAL"
else
  BASE="$SUPABASE_URL_REMOTE"
fi

echo "== Smoke mode: $MODE =="

echo "1) REST root"
curl -si "$BASE/rest/v1/" | head -n 1

echo "2) Health function"
curl -si "$BASE/functions/v1/health" | head -n 1

echo "3) user-profile (requires USER_JWT)"
if [[ -z "${USER_JWT:-}" ]]; then
  echo "   USER_JWT not set; skipping user-profile test"
else
  curl -si "$BASE/functions/v1/user-profile" -H "Authorization: Bearer $USER_JWT" | head -n 1
fi

echo "OK"
