#!/usr/bin/env bash
set -euo pipefail
: "${FUNC_URL:?}"

out=$(curl -fsS "$FUNC_URL/iam/canary")
echo "$out" | jq -e '.ok==true' >/dev/null
echo "✅ sso/scim canary ok"
