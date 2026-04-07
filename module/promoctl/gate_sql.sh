#!/usr/bin/env bash
set -euo pipefail
: "${SUPABASE_DB_URL:?}"
psql "$SUPABASE_DB_URL" -c "select to_regclass('public.ai_model_serving');"
psql "$SUPABASE_DB_URL" -c "select to_regclass('public.ai_model_rollouts');"
psql "$SUPABASE_DB_URL" -c "explain analyze select * from public.ai_model_rollouts where model_key='eta' order by updated_at desc limit 1;"
echo "✅ promoctl SQL gates"
