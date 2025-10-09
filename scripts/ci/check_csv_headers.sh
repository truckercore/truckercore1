#!/usr/bin/env bash
set -euo pipefail

URL="${BASE_URL:-http://localhost:3000}/api/exports/alerts.csv"
AUTH="${JWT:-}"

HDRS=$(mktemp)
OUT=$(mktemp)

if [[ -n "${AUTH}" ]]; then
  curl -sS -D "${HDRS}" -H "Authorization: Bearer ${AUTH}" "${URL}" -o "${OUT}"
else
  curl -sS -D "${HDRS}" "${URL}" -o "${OUT}"
fi

grep -qi "^X-Export-Id:" "${HDRS}"
grep -qi "^X-Row-Count:" "${HDRS}"
grep -qi "^X-Checksum-SHA256:" "${HDRS}"
grep -qi "^Cache-Control: no-store" "${HDRS}"

# checksum match
CHK=$(grep -i "^X-Checksum-SHA256:" "${HDRS}" | awk -F': ' '{print $2}' | tr -d '\r')
if command -v sha256sum >/dev/null 2>&1; then
  SUM=$(sha256sum "${OUT}" | awk '{print $1}')
else
  SUM=$(shasum -a 256 "${OUT}" | awk '{print $1}')
fi

if [[ "${CHK}" != "${SUM}" ]]; then
  echo "Checksum mismatch: header=${CHK} file=${SUM}" >&2
  exit 2
fi

echo "CSV headers OK"
