#!/usr/bin/env bash
set -euo pipefail
: "${SUPABASE_DB_URL:?SUPABASE_DB_URL missing}"
mkdir -p reports
psql -At "$SUPABASE_DB_URL" -c \
"select model_key,
        status as strategy,
        null as active_version_id,
        baseline_version_id as control_version_id,
        candidate_version_id,
        pct as canary_pct
   from ai_model_rollouts
  order by model_key" > reports/promo_state_current.txt

if [ -f reports/promo_state_baseline.txt ]; then
  diff -u reports/promo_state_baseline.txt reports/promo_state_current.txt || true
else
  echo "[warn] no baseline file to compare against"
fi
