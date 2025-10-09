#!/usr/bin/env bash
set -euo pipefail
# Basic visibility (adjust per RLS in harness)
psql "$SUPABASE_DB_URL" -c "select count(*) from roadside_requests where status in ('new','assigned') limit 1;"
# Index plan: provider search by time/geo (example)
psql "$SUPABASE_DB_URL" -c "explain analyze select id from roadside_requests where status='new' order by created_at desc limit 50;"
echo "✅ roadside SQL gates executed"
