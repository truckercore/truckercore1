#!/usr/bin/env bash
set -euo pipefail
: "${FUNC_URL:?}" "${ROTATOR:?}" "${KEY_NAME:?}"
SHA="${SHA:-""}" EVID="${EVID:-""}"

curl -fsS -X POST "$FUNC_URL/sec/record_rotation" -H 'content-type: application/json' \
  -d "{\"key_name\":\"$KEY_NAME\",\"rotated_by\":\"$ROTATOR\",\"sha256_pub\":\"$SHA\",\"evidence_url\":\"$EVID\"}"
echo "✅ rotation recorded"
