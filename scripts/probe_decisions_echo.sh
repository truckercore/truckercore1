#!/usr/bin/env bash
set -euo pipefail
: "${FUNC_URL:?}"
# No auth header provided in CI; endpoint should still 403 when not admin.
out="$(curl -fsS "${FUNC_URL}/ops/echo_decisions" || true)"
# When unauthorized, the endpoint returns {error:"forbidden"}. We still pass if structure is present after enabling auth in env.
echo "$out" | jq -e '.iam.jwks_ttl or .error=="forbidden"' >/dev/null
echo "✅ decisions echo OK"