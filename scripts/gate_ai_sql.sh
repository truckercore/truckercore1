#!/usr/bin/env bash
set -euo pipefail
: "${SUPABASE_DB_URL:?}"

echo "== Core AI tables present =="
psql "$SUPABASE_DB_URL" -c "select to_regclass('public.ai_models');"
psql "$SUPABASE_DB_URL" -c "select to_regclass('public.ai_model_versions');"
psql "$SUPABASE_DB_URL" -c "select to_regclass('public.ai_inference_events');"
psql "$SUPABASE_DB_URL" -c "select to_regclass('public.ai_feedback_events');"
psql "$SUPABASE_DB_URL" -c "select to_regclass('public.ai_accuracy_rollups');"
psql "$SUPABASE_DB_URL" -c "select to_regclass('public.ai_drift_snapshots');"

echo "== Index probes (explain analyze) =="
psql "$SUPABASE_DB_URL" -c "explain analyze select * from public.ai_inference_events where model_key='eta' order by created_at desc limit 50;"
psql "$SUPABASE_DB_URL" -c "explain analyze select * from public.ai_feedback_events where correlation_id in (select correlation_id from public.ai_inference_events order by created_at desc limit 200);"

echo "== RLS enabled on raw tables =="
for t in ai_inference_events ai_feedback_events ai_training_jobs; do
  rls=$(psql "$SUPABASE_DB_URL" -At -c "select relrowsecurity from pg_class where oid='public.$t'::regclass;")
  [ "$rls" = "t" ] || { echo "❌ RLS not enabled on $t"; exit 3; }
done

echo "== Rollup functions present (optional) =="
psql "$SUPABASE_DB_URL" -c "select to_regprocedure('public.ai_eta_rollup(int)');" || true
psql "$SUPABASE_DB_URL" -c "select to_regprocedure('public.ai_eta_drift_snapshot(int)');" || true

echo "✅ AI SQL gates ok"
