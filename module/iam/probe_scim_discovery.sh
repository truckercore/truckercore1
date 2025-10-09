#!/usr/bin/env bash
set -euo pipefail

: "${FUNC_URL:?}" : "${SCIM_TOKEN:?}"

H=( -H "Authorization: Bearer $SCIM_TOKEN" -H "content-type: application/scim+json" )

# ServiceProviderConfig present
curl -fsS "$FUNC_URL/scim/v2/ServiceProviderConfig" "${H[@]}" \
| jq -e '.schemas[] | contains("ServiceProviderConfig")' >/dev/null

# ResourceTypes and Schemas present
curl -fsS "$FUNC_URL/scim/v2/ResourceTypes" "${H[@]}" \
| jq -e '.Resources|length>=2' >/dev/null

curl -fsS "$FUNC_URL/scim/v2/Schemas" "${H[@]}" \
| jq -e '.Resources|length>=2' >/dev/null

# Bulk returns 501 SCIM error
rc=$(curl -s -o >(jq .) -w "%{http_code}" -X POST "$FUNC_URL/scim/v2/Bulk" "${H[@]}" -d '{}')
[ "$rc" = "501" ] || { echo "❌ /Bulk expected 501"; exit 5; }

# sortBy/sortOrder rejected with 400
rc=$(curl -s -o >(jq .) -w "%{http_code}" "$FUNC_URL/scim/v2/Users?sortBy=userName&sortOrder=ascending" "${H[@]}")
[ "$rc" = "400" ] || { echo "❌ sortBy/sortOrder should be 400"; exit 6; }

echo "✅ SCIM discovery/unsupported/sort probes OK"
