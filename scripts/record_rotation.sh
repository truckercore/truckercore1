#!/usr/bin/env bash
set -euo pipefail
: "${FUNC_URL:?}" "${KEY_NAME:?}" "${ROTATOR:?}"

curl -fsS -X POST "$FUNC_URL/sec/record_rotation" -H 'content-type: application/json' \
  -d "{\"key_name\":\"$KEY_NAME\",\"rotated_by\":\"$ROTATOR\"}"
echo "✅ rotation logged"
