#!/usr/bin/env bash
set -euo pipefail
: "${FUNC_URL:?}" "${ORG_ID:?}" "${ORG_NAME:?}"

# Trigger export and capture timing header
headers=$(curl -fsS -X POST "$FUNC_URL/roi/report_monthly_pdf" -H 'content-type: application/json' \
  -d "{\"org_id\":\"$ORG_ID\",\"org_name\":\"$ORG_NAME\",\"force\":true}" -D - -o /dev/null)

# Extract x-exec-report-ms
ms=$(awk '/^x-exec-report-ms:/ {print $2}' <<<"$headers" | tr -d '\r')
ms=${ms:-9999}
if [ "$ms" -le 2000 ]; then
  echo "✅ export p95 ≤2s ($ms ms)"
else
  echo "❌ export p95 gate >2s ($ms ms)"
  exit 2
fi
