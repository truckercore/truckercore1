#!/usr/bin/env bash
set -euo pipefail
: "${FUNC_URL:?}"
: "${ORG_ID:=00000000-0000-0000-0000-00000000ABCD}"

curl -fsS "$FUNC_URL/roi/export_rollup?org_id=$ORG_ID" | jq '.'
