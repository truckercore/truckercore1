#!/usr/bin/env bash
set -euo pipefail
: "${PROJECT_URL:?PROJECT_URL is required}"

curl -sS -m 15 -f "${PROJECT_URL}/" >/dev/null
printf "HTTP health OK at %s\n" "${PROJECT_URL}"
