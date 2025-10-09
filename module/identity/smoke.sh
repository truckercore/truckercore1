#!/usr/bin/env bash
set -euo pipefail
: "${FUNC_URL:?}" : "${SCIM_BEARER_TOKEN:=scim_secret_example}"
# Simple OPTIONS reachability checks for SCIM and SAML endpoints
for path in scim-users scim-groups saml-metadata saml-acs; do
  url="${FUNC_URL%/}/$path"
  code=$(curl -sS -o /dev/null -w "%{http_code}" -X OPTIONS "$url" || true)
  [[ "$code" == "200" || "$code" == "204" ]] || { echo "❌ $path not reachable (HTTP $code)"; exit 3; }
  echo "✅ $path reachable"
done
echo "✅ identity smoke passed"
