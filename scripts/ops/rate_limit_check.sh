#!/usr/bin/env bash
set -euo pipefail
# Usage:
#   PROJECT=<REF> ./scripts/ops/rate_limit_check.sh      # remote
#   BASE=http://127.0.0.1:54321 ./scripts/ops/rate_limit_check.sh  # local
# Optional: COUNT=50

COUNT=${COUNT:-50}
BASE=${BASE:-https://${PROJECT}.supabase.co}

if [[ -z "${BASE}" ]]; then
  echo "Set PROJECT=<ref> or BASE=<url>" >&2
  exit 1
fi

URL="$BASE/functions/v1/health"
echo "Hitting $URL $COUNT times..."
for i in $(seq 1 $COUNT); do
  code=$(curl -s -o /dev/null -w "%{http_code}" "$URL")
  printf "%s\n" "$code"
done
