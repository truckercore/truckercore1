#!/usr/bin/env bash
set -euo pipefail
: "${SUPABASE_DB_URL:?}"

# Exactly one active per model (constraint/trigger should enforce)
violations=$(psql -At "$SUPABASE_DB_URL" -c "
  select model_key
  from (
    select model_key, count(*) filter (where status='active') as active_cnt
    from ai_model_serving
    group by 1
  ) t
  where active_cnt <> 1;
")
if [ -n "$violations" ]; then
  echo "❌ multiple/zero active versions detected:"
  echo "$violations"
  # Emit a metric you can scrape/ship as promo_active_violation_total
  exit 2
fi

# Canary pct bounded + monotonic guard (illegal update must fail)
set +e
psql "$SUPABASE_DB_URL" <<'SQL'
begin;
update ai_model_rollouts
   set canary_pct = 5
 where model_key = 'eta' and canary_pct > 5;
rollback;
SQL
rc=$?
set -e
if [ $rc -eq 0 ]; then
  echo "❌ monotonic canary guard not enforced"
  exit 3
fi

echo "✅ promo SQL invariants"
