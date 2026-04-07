#!/usr/bin/env bash
set -euo pipefail
: "${FUNC_URL:?}"; : "${TEST_JWT:?}"; : "${SUPABASE_DB_URL:?}"
# create conversation row for the test user
CID=$(psql -At "$SUPABASE_DB_URL" -c "insert into ai_conversations(user_id,title) values ('00000000-0000-0000-0000-000000000001','Smoke') returning id;")
curl -fsS -X POST "$FUNC_URL/ai_suggest" -H "authorization: $TEST_JWT" -H "content-type: application/json" \
  -d "{\"conv_id\":\"$CID\",\"message\":\"hello\"}" | grep -q '"reply"'
echo "✅ ai smoke passed"
