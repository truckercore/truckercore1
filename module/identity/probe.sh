#!/usr/bin/env bash
set -euo pipefail
: "${FUNC_URL:?}" : "${SCIM_BEARER_TOKEN:=scim_secret_example}" ; : "${REPORT_DIR:=./reports}"
. "$(dirname "$0")/../../scripts/lib_probe.sh"
N="${N:-6}"
mkdir -p "$REPORT_DIR"
seq 1 $N | while read -r _; do
  t0=$(date +%s%3N)
  curl -fsS -X POST "${FUNC_URL%/}/scim-users?org_id=00000000-0000-0000-0000-0000000000F1" \
    -H "Authorization: Bearer $SCIM_BEARER_TOKEN" -H "Content-Type: application/scim+json" \
    -d '{"userName":"probe@example.com","emails":[{"value":"probe@example.com"}],"name":{"givenName":"Probe","familyName":"User"}}' >/dev/null || true
  echo $(( $(date +%s%3N) - t0 ))
done | compute_p95 "identity" "scim_users_create" >/dev/null
P95=$(sed -n 's/.*"p95_ms":\([0-9]*\).*/\1/p' "$REPORT_DIR/identity_scim_users_create_probe.json")
[ -n "$P95" ] && [ "$P95" -le "${IDENTITY_SCIM_P95_MS:-1200}" ] || { echo "❌ identity p95=${P95}"; exit 4; }
echo "✅ identity probe"
