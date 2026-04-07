#!/usr/bin/env bash
set -euo pipefail
: "${SUPABASE_DB_URL:?}"
psql "$SUPABASE_DB_URL" -c "select public.ai_eta_drift_snapshot(60);" >/dev/null
psql "$SUPABASE_DB_URL" -c "select public.ai_eta_rollup(60);" >/dev/null
echo "✅ ai-drift smoke"