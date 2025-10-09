#!/usr/bin/env bash
set -euo pipefail
: "${SUPABASE_DB_URL:?}"

# Invariant: one active serving row per model_key
# Expect zero rows from the assertion query; otherwise fail.
Q="select model_key, count(*) filter (where 1=1) as serving_rows
   from public.ai_model_serving
   group by model_key
   having count(*) <> 1;"

rows=$(psql -At "$SUPABASE_DB_URL" -c "$Q" | wc -l | tr -d ' ')
if [ "${rows:-0}" -ne 0 ]; then
  echo "❌ Invariant failed: ai_model_serving must have exactly one row per model_key; found $rows offending key(s)"
  psql -At "$SUPABASE_DB_URL" -c "$Q"
  exit 3
fi

# Canary monotonicity is enforced by DB triggers; we can optionally smoke an EXPLAIN to ensure table exists
psql "$SUPABASE_DB_URL" -c "explain analyze select * from public.ai_model_rollouts where status='canary' order by updated_at desc limit 1;" >/dev/null

echo "✅ Promotion invariants OK"
