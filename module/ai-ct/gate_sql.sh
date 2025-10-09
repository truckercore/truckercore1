#!/usr/bin/env bash
set -euo pipefail
: "${SUPABASE_DB_URL:?}"

# Verify RCA function and core CT tables exist
psql "$SUPABASE_DB_URL" -c "select to_regprocedure('public.ai_eta_rca(int)');" | grep -qi ai_eta_rca || { echo "❌ ai_eta_rca missing"; exit 3; }
psql "$SUPABASE_DB_URL" -c "select to_regclass('public.ai_inference_events');" | grep -qi ai_inference_events
psql "$SUPABASE_DB_URL" -c "select to_regclass('public.ai_feedback_events');" | grep -qi ai_feedback_events

echo "✅ ai-ct SQL gates executed"
