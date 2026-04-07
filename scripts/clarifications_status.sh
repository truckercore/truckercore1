#!/usr/bin/env bash
set -euo pipefail
missing=0
grep -q "jwks_ttl:" config/decisions.yml || { echo "Missing: jwks_ttl"; missing=1; }
grep -q "bulk_deactivate_cap:" config/decisions.yml || { echo "Missing: SCIM bulk cap"; missing=1; }
grep -q "required_factors:" config/decisions.yml || { echo "Missing: AI required_factors"; missing=1; }
if [ $missing -eq 0 ]; then
  echo "✅ Clarifications complete"
else
  exit 1
fi
