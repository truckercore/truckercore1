#!/usr/bin/env bash
set -euo pipefail
: "${FUNC_URL:?}"
org="00000000-0000-0000-0000-00000000ABCD"
org_name="Gate Test"

code=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST "$FUNC_URL/roi/report_monthly_pdf" \
  -H 'content-type: application/json' \
  -d "{\"org_id\":\"$org\",\"org_name\":\"$org_name\"}")

[ "$code" -eq 403 ] || { echo "❌ expected 403"; exit 2; }
echo "✅ exec_analytics gate enforced"
