#!/usr/bin/env bash
set -euo pipefail
: "${SUPABASE_DB_URL:?}"
row="$(psql -At "$SUPABASE_DB_URL" -c "select coalesce(n_pred,0),coalesce(n_fb,0),coalesce(psi,0),coalesce(p95_ms,0) from ai_health")"
IFS='|' read -r preds fbs psi p95 <<<"$row"
[ "${preds:-0}" -ge 1 ] || { echo "❌ AI health: no predictions in 24h"; exit 2; }
[ "${p95:-0}" -le "${AI_ETA_P95_MS:-1200}" ] || { echo "❌ AI health: p95 too high ($p95)"; exit 3; }
echo "✅ AI health OK (preds=$preds fb=$fbs psi=$psi p95=$p95)"
