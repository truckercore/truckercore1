#!/usr/bin/env bash
set -euo pipefail

if ! command -v yq >/dev/null 2>&1; then
  echo "yq is required to validate decisions.yml" >&2
  exit 2
fi

yq '.iam.jwks_ttl, .iam.invalidate_on, .iam.scim.bulk_deactivate_cap, .ai.ranking.required_factors' config/decisions.yml >/dev/null

echo "✅ decisions.yml has required keys"
