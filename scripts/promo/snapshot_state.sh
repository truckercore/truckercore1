#!/usr/bin/env bash
set -euo pipefail
: "${DATABASE_URL:?}"
OUT=${1:-reports/promo_state_current.txt}
mkdir -p "$(dirname "$OUT")"
psql -At "$DATABASE_URL" -c "select model_key, active_version_id, candidate_version_id, pct as canary_pct from public.ai_model_rollouts order by model_key" > "$OUT"
echo "[snapshot] wrote $OUT"
