#!/usr/bin/env bash
set -euo pipefail
need=(FUNC_URL TEST_JWT SUPABASE_DB_URL)
for v in "${need[@]}"; do
  [ -n "${!v:-}" ] || { echo "Missing env: $v"; exit 1; }
fi
for k in ai_eta_predict ai_eta_feedback ai_match_score ai_fraud_detect xai_eta_explain; do
  ./scripts/resolve_fn.sh "$k" >/dev/null
done
echo "✅ AI env + endpoint map OK"
