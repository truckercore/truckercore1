#!/usr/bin/env bash
set -euo pipefail
: "${SUPABASE_DB_URL:?}"
psql "$SUPABASE_DB_URL" -c "select count(*) from roadside_requests where status in ('new','assigned') limit 1;"
psql "$SUPABASE_DB_URL" -c "explain analyze select id from roadside_requests where status='new' order by created_at desc limit 20;"
echo "✅ roadside SQL gates executed"
