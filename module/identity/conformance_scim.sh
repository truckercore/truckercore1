#!/usr/bin/env bash
set -euo pipefail
: "${FUNC_URL:?}" : "${SCIM_TOKEN:?}" : "${ORG_ID:?}"

base="${FUNC_URL%/}/scim-users?org_id=${ORG_ID}"
hdr=(-H "Authorization: Bearer $SCIM_TOKEN" -H "content-type: application/scim+json")

ext="ext-$(uuidgen 2>/dev/null || openssl rand -hex 8)"
create=$(curl -fsS -X POST "$base" "${hdr[@]}" -d "{\"userName\":\"$ext\",\"externalId\":\"$ext\",\"emails\":[{\"value\":\"$ext@example.com\"}]}")
id=$(echo "$create" | jq -r .id)
[ -n "$id" ] || { echo "❌ create failed"; exit 3; }

# Fetch to get ETag
etag=$(curl -fsS "$base/$id" "${hdr[@]}" -i | awk -F': ' '/^etag:/I {print $2}' | tr -d '\r')
[ -n "$etag" ] || { echo "❌ missing ETag"; exit 3; }

# Deactivate with If-Match
curl -fsS -X PATCH "$base/$id" "${hdr[@]}" -H "If-Match: $etag" \
  -d '{"Operations":[{"op":"Replace","path":"active","value":false}]}' >/dev/null

# Bad ETag must 412
set +e
bad=$(curl -s -o /dev/stderr -w "%{http_code}" -X PATCH "$base/$id" "${hdr[@]}" -H 'If-Match: W/"deadbeef"' \
  -d '{"Operations":[{"op":"Replace","path":"active","value":true}]}')
set -e
[ "$bad" = "412" ] || { echo "❌ expected 412 If-Match"; exit 4; }

# Idempotent create should 200
rc=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$base" "${hdr[@]}" \
  -d "{\"userName\":\"$ext\",\"externalId\":\"$ext\",\"emails\":[{\"value\":\"$ext@example.com\"}]}")
[ "$rc" = "200" ] || { echo "❌ idempotent create expected 200"; exit 5; }

echo "✅ SCIM CRUD + ETag/If-Match OK"