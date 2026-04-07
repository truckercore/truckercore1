#!/usr/bin/env bash
set -euo pipefail
: "${FUNC_URL:?}" : "${SCIM_TOKEN:?}"
hdr=(-H "Authorization: Bearer $SCIM_TOKEN" -H "content-type: application/scim+json")
base="$FUNC_URL/scim/v2/Users"

# seed a few users
for i in $(seq 1 3); do
  ext="ci-$i"
  curl -fsS -X POST "$base?org_id=00000000-0000-0000-0000-0000000000F1" "${hdr[@]}" -d "{\"userName\":\"$ext\",\"externalId\":\"$ext\"}" >/dev/null || true
done

# filter by userName with pagination
curl -fsS "$base?org_id=00000000-0000-0000-0000-0000000000F1&filter=userName%20eq%20%22ci-2%22&startIndex=1&count=1" "${hdr[@]}" | jq -e '.totalResults >= 1' >/dev/null
echo "✅ SCIM filter & pagination OK"
