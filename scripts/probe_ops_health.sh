#!/usr/bin/env bash
set -euo pipefail
: "${FUNC_URL:?}"
out="$(curl -fsS "$FUNC_URL/ops/health")"
echo "$out" | jq -e '.sso and .scim and .state_latency_ms_p95' >/dev/null
echo "✅ ops health OK"