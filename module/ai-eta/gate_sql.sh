#!/usr/bin/env bash
set -euo pipefail
: "${SUPABASE_DB_URL:?}"
# Check core registry tables and functions exist
psql "$SUPABASE_DB_URL" -c "select to_regclass('public.ai_models');" | grep -qi ai_models
psql "$SUPABASE_DB_URL" -c "select to_regclass('public.ai_model_versions');" | grep -qi ai_model_versions
psql "$SUPABASE_DB_URL" -c "select to_regclass('public.ai_rollouts');" | grep -qi ai_rollouts
psql "$SUPABASE_DB_URL" -c "select to_regclass('public.ai_inference_events');" | grep -qi ai_inference_events
psql "$SUPABASE_DB_URL" -c "select to_regclass('public.ai_feedback_events');" | grep -qi ai_feedback_events
psql "$SUPABASE_DB_URL" -c "select to_regclass('public.ai_training_jobs');" | grep -qi ai_training_jobs
psql "$SUPABASE_DB_URL" -c "select to_regclass('public.ai_accuracy_rollups');" | grep -qi ai_accuracy_rollups
psql "$SUPABASE_DB_URL" -c "select to_regclass('public.ai_drift_snapshots');" | grep -qi ai_drift_snapshots
# Function exists
psql "$SUPABASE_DB_URL" -c "select proname from pg_proc where proname='ai_get_serving_version'" | grep -qi ai_get_serving_version
psql "$SUPABASE_DB_URL" -c "select proname from pg_proc where proname in ('ai_eta_feedback_since','ai_eta_rollup','ai_eta_drift_snapshot');" | grep -qi ai_eta_feedback_since
echo "✅ ai-eta SQL gates executed"
