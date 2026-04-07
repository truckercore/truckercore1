#!/usr/bin/env bash
set -euo pipefail
: "${FUNC_URL:?}"; : "${TEST_JWT:?}"; : "${SUPABASE_DB_URL:?}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "$DIR/../../scripts/lib_probe.sh"
CID=$(psql -At "$SUPABASE_DB_URL" -c "insert into ai_conversations(user_id,title) values ('00000000-0000-0000-0000-000000000001','Probe') returning id;")
N="${N:-10}"
seq 1 "$N" | while read -r _; do
  t0=$(date +%s%3N)
  curl -fsS -X POST "$FUNC_URL/ai_suggest" -H "authorization: $TEST_JWT" -H "content-type: application/json" \
    -d "{\"conv_id\":\"$CID\",\"message\":\"tip?\"}" > /dev/null
  echo $(( $(date +%s%3N) - t0 ))
done | compute_p95 "ai" "suggest" >/dev/null
P95=$(sed -n 's/.*"p95_ms":\([0-9]*\).*/\1/p' "$REPORT_DIR/ai_suggest_probe.json")
[ -n "$P95" ] && [ "$P95" -le "${AI_P95_MS:-1200}" ] || { echo "❌ p95=${P95}ms"; exit 4; }
echo "✅ ai probe SLO ok"
