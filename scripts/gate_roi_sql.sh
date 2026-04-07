#!/usr/bin/env bash
set -euo pipefail
: "${SUPABASE_DB_URL:?SUPABASE_DB_URL required}"

psql "$SUPABASE_DB_URL" -qc "select to_regclass('public.ai_roi_events');"
psql "$SUPABASE_DB_URL" -qc "select to_regclass('public.ai_roi_rollup_day');"
echo "✅ ROI SQL present"
