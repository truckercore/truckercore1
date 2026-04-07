#!/usr/bin/env bash
set -euo pipefail
: "${FUNC_URL:?}" "${ORG_ID:?}" "${SCIM_DEACTIVATE_CONFIRM:?}"

# Expect dry_run_required when not providing confirm_token and dry_run=false
code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$FUNC_URL/scim/bulk_deactivate" \
  -H 'content-type: application/json' \
  -d "{\"org_id\":\"$ORG_ID\",\"user_ids\":[\"x\"],\"dry_run\":false}")
[ "$code" -eq 400 ] || { echo "❌ expected 400 dry_run_required"; exit 2; }

# Expect cap enforcement when sending too many ids
IDs=$(python - <<'PY'
print('", "'.join([f"u{i}" for i in range(1000)]))
PY
)
code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$FUNC_URL/scim/bulk_deactivate" \
  -H 'content-type: application/json' \
  -d "{\"org_id\":\"$ORG_ID\",\"user_ids\":[\"$IDs\"],\"confirm_token\":\"$SCIM_DEACTIVATE_CONFIRM\"}")
[ "$code" -eq 422 ] || { echo "❌ expected 422 too_many"; exit 3; }

echo "✅ SCIM dry-run & cap OK"