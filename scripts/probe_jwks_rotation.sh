#!/usr/bin/env bash
set -euo pipefail
: "${FUNC_URL:?}"
resp="$(curl -fsS "$FUNC_URL/iam/test_jwks_rotation")"
echo "$resp" | jq -e '.ok==true and .a != .b' >/dev/null
echo "✅ JWKS rotation/invalidations OK"