#!/usr/bin/env bash
set -euo pipefail
: "${FUNC_URL:?}"
curl -fsS "$FUNC_URL/poi/parking?bbox=-93.8,41.5,-93.4,41.8" >/dev/null
echo "✅ pois smoke passed"
