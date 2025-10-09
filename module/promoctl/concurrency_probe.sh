#!/usr/bin/env bash
set -euo pipefail
: "${SUPABASE_DB_URL:?}"
: "${REPORT_DIR:=./reports}"

sql() { psql -At "$SUPABASE_DB_URL" -c "$1"; }

# Fire N concurrent 'increase_canary' to random pct; expect monotonic end-state
N="${N:-8}"
par() { ( sql "select ai_promote_tx('eta','increase_canary', null, $1, 'ci-probe');" ) & }

for p in 10 20 30 40 50 60 70 80; do par "$p"; done
wait

# Validate serving table has exactly one row for eta (PK guarantees at most one; ensure exists)
rows=$(sql "select count(*) from ai_model_serving where model_key='eta';")
[ "${rows:-0}" = "1" ] || { echo "❌ serving invariant failed (rows=$rows)"; exit 2; }

# Validate canary pct monotonic end-state: should be >= max attempted (80)
pct=$(sql "select coalesce(pct,0) from ai_model_rollouts where model_key='eta';")
[ -n "${pct}" ] && [ "${pct}" -ge 80 ] || { echo "❌ canary pct not monotonic end-state (pct=${pct:-nil})"; exit 3; }

mkdir -p "$REPORT_DIR"
printf '{"module":"promoctl","probe":"concurrency","ok":true,"ts":"%s"}\n' "$(date -Is)" > "$REPORT_DIR/promoctl_concurrency.json"

echo "✅ concurrency probe"
