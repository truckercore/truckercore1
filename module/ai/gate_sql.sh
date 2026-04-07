#!/usr/bin/env bash
set -euo pipefail
: "${SUPABASE_DB_URL:?}"
psql "$SUPABASE_DB_URL" -c "select to_regclass('public.idx_ai_msg_conv_time');" | grep -qi idx_ai_msg_conv_time
psql "$SUPABASE_DB_URL" -c "select to_regclass('public.ai_predictions');" | grep -qi ai_predictions
psql "$SUPABASE_DB_URL" -c "select to_regclass('public.idx_ai_pred_module_time');" | grep -qi idx_ai_pred_module_time
psql "$SUPABASE_DB_URL" -c "select to_regclass('public.ai_metrics');" | grep -qi ai_metrics
psql "$SUPABASE_DB_URL" -c "select to_regclass('public.ai_feature_summaries');" | grep -qi ai_feature_summaries
psql "$SUPABASE_DB_URL" -c "select to_regclass('public.ai_drift');" | grep -qi ai_drift
psql "$SUPABASE_DB_URL" -c "select to_regclass('public.ai_roi');" | grep -qi ai_roi
echo "✅ ai SQL gates executed"
