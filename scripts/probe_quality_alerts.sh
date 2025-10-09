#!/usr/bin/env bash
set -euo pipefail
: "${FUNC_URL:?}" "${SUPABASE_DB_URL:?}"

curl -fsS "$FUNC_URL/quality/cron.check" >/dev/null
cnt=$(psql -At "$SUPABASE_DB_URL" -c "select count(*) from quality_alerts where created_at>now()-interval '10 minutes'")
[ "$cnt" -ge 0 ] || { echo "❌ quality alert count unreadable"; exit 2; }
echo "✅ quality job OK ($cnt rows in last 10m)"