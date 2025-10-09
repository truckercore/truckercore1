#!/usr/bin/env bash
set -euo pipefail
: "${FUNC_URL:?}" "${ORG_ID:?}"

resp="$(curl -fsS "$FUNC_URL/scim/v2/Users?startIndex=1&count=50&org_id=$ORG_ID")"
echo "$resp" | jq -e '.Resources and .itemsPerPage==50' >/dev/null
echo "✅ SCIM Users pagination contract ok"
