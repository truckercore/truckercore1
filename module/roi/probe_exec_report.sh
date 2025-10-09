#!/usr/bin/env bash
set -euo pipefail
: "${FUNC_URL:?}"

org="00000000-0000-0000-0000-00000000ABCD"
org_name="Demo Fleet"

# Expect 403 when entitlement is off
code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$FUNC_URL/roi/report_monthly_pdf" -H 'content-type: application/json' -d "{\"org_id\":\"$org\",\"org_name\":\"$org_name\"}")
if [ "$code" -ne 403 ]; then echo "❌ expected 403 when entitlement off"; exit 2; fi

# Force run to bypass idempotency and validate response fields
resp=$(curl -fsS -X POST "$FUNC_URL/roi/report_monthly_pdf" -H 'content-type: application/json' -d "{\"org_id\":\"$org\",\"org_name\":\"$org_name\",\"force\":true}")
echo "$resp" | jq -e '.checksum and .path' >/dev/null || { echo "❌ missing checksum/path"; exit 3; }
echo "✅ exec report probe ok"