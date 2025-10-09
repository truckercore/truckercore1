#!/usr/bin/env bash
set -euo pipefail
: "${FUNC_URL:?}" "${ORG_ID:?}" "${SUPABASE_DB_URL:?}"

curl -fsS "$FUNC_URL/ai/probe_ranking_sample?org_id=$ORG_ID" >/dev/null
psql -At "$SUPABASE_DB_URL" -c "select factors ? 'distance' and factors ? 'price' from ai_rank_factors order by created_at desc limit 1" | grep -q t
echo "✅ AI factors logged OK"