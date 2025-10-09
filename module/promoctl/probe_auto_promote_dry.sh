#!/usr/bin/env bash
set -euo pipefail
: "${FUNC_URL:?}"
curl -fsS "$FUNC_URL/ai_ct/cron.auto_promote?dry=1" | jq -e '.ok==true' >/dev/null
echo "✅ auto-promote dry-run OK"
