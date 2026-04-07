#!/usr/bin/env bash
set -euo pipefail
# Create request
REQ=$(curl -fsS -X POST "$FUNC_URL/roadside-match" \
  -H "authorization: $TEST_JWT" -H "content-type: application/json" \
  -d '{"lat":41.6,"lng":-93.6,"service_type":"tire"}')
echo "$REQ" | grep -q '"candidates"'
PROVIDER_ID=$(echo "$REQ" | sed -n 's/.*"provider_id":"\([^"]*\)".*/\1/p' | head -1)

# Create placeholder request (if needed)
REQ_ID=$(psql "$SUPABASE_DB_URL" -At -c \
"insert into roadside_requests(lat,lng,service_type,status) values (41.6,-93.6,'tire','new') returning id;")

# Accept
ACC=$(curl -fsS -X POST "$FUNC_URL/roadside-accept" \
  -H "authorization: $SERVICE_TOKEN" -H "content-type: application/json" \
  -d "{\"request_id\":\"$REQ_ID\",\"provider_id\":\"$PROVIDER_ID\",\"tech_id\":null}")
echo "$ACC" | grep -q '"status":"assigned"'
echo "✅ roadside smoke passed"
