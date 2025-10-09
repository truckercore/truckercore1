#!/usr/bin/env bash
set -euo pipefail
# Usage: ./scripts/resolve_fn.sh ai_eta_predict
KEY="${1:?endpoint key}"
FILE="$(dirname "$0")/ai_endpoints.json"
val="$(jq -r --arg k "$KEY" '.[$k] // empty' "$FILE")"
[ -n "$val" ] || { echo "ERR: unknown endpoint key: $KEY" >&2; exit 2; }
echo "$val"
