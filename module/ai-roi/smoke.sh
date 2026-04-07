#!/usr/bin/env bash
set -euo pipefail
: "${SUPABASE_DB_URL:?}"
psql "$SUPABASE_DB_URL" -c "select to_regclass('public.ai_roi');" | grep -qi ai_roi && echo "✅ ai-roi table"