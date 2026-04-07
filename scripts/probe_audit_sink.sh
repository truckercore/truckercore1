#!/usr/bin/env bash
set -euo pipefail
: "${SUPABASE_DB_URL:?}"

# Insert a probe event and verify it shows up in the last 5 minutes
psql "$SUPABASE_DB_URL" -c "insert into audit_events(action,entity,metadata) values('ops_probe','env','{\"ok\":true}')" >/dev/null
psql -At "$SUPABASE_DB_URL" -c "select count(*) from audit_events where action='ops_probe' and created_at>now()-interval '5 minutes'" | grep -q '1'
echo "✅ audit sink ok"
