#!/usr/bin/env bash
set -euo pipefail
: "${SUPABASE_DB_URL:?}"
# Minimal gate: ensure inference events table exists (xai depends on it)
psql "$SUPABASE_DB_URL" -c "select to_regclass('public.ai_inference_events');" | grep -qi ai_inference_events

echo "✅ xai SQL gates executed"
