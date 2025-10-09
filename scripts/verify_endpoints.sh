#!/usr/bin/env bash
set -euo pipefail
: "${FUNC_URL:?}" : "${TEST_JWT:?}"

REG="$(dirname "$0")/ai_endpoints.json"
keys=( $(jq -r 'keys[]' "$REG") )

fail=0
for k in "${keys[@]}"; do
  path="$(jq -r --arg k "$k" '.[$k]' "$REG")"
  url="${FUNC_URL%/}/$path"
  echo "→ Checking $k @ $url"
  code=$(curl -sS -o /dev/null -w "%{http_code}" \
    -H "authorization: $TEST_JWT" -H "content-type: application/json" \
    -X OPTIONS "$url" || true)
  if [[ "$code" != "200" && "$code" != "204" ]]; then
    echo "❌ $k: endpoint not reachable (HTTP $code)"; fail=1
  else
    echo "✅ $k reachable"
  fi
done
exit $fail
