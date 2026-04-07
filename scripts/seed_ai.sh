#!/usr/bin/env bash
set -euo pipefail
: "${SUPABASE_DB_URL:?}"; : "${ETA_MODEL_ENDPOINT:?}"; : "${MATCH_MODEL_ENDPOINT:?}"; : "${FRAUD_MODEL_ENDPOINT:?}"

psql "$SUPABASE_DB_URL" \
  -v ETA_MODEL_ENDPOINT="'$ETA_MODEL_ENDPOINT'" \
  -v MATCH_MODEL_ENDPOINT="'$MATCH_MODEL_ENDPOINT'" \
  -v FRAUD_MODEL_ENDPOINT="'$FRAUD_MODEL_ENDPOINT'" \
  -f db/seeds/ai_bootstrap.sql

echo "✅ AI seed complete"
