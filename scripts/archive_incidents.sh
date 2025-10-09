#!/usr/bin/env bash
# scripts/archive_incidents.sh
# Archive incidents to S3 with environment guard
set -euo pipefail

: "${ENV:?Set ENV=prod|staging}"

if [ "$ENV" = "prod" ] && [ -z "${CI:-}" ]; then
  echo "Refusing prod archival outside CI" >&2
  exit 1
fi

echo "[archive] proceeding in ENV=$ENV (guard passed)"
# TODO: invoke jobs/archive_incidents.mjs with required env variables
# node jobs/archive_incidents.mjs
exit 0
