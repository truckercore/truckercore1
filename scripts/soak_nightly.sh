#!/usr/bin/env bash
set -euo pipefail
: "${FUNC_URL:?}"

k6 run -e FUNC_URL="$FUNC_URL" --duration 30m --vus 60 k6/market_scenarios.js
