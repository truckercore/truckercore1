#!/usr/bin/env bash
set -euo pipefail
# Window validity
psql "$SUPABASE_DB_URL" -c "select count(*) from fleet_discounts where start_at<=now() and end_at>=now();" | grep -q '[1-9]'
# Index for fleet+time
psql "$SUPABASE_DB_URL" -c "explain analyze select id from fleet_discounts where fleet_org_id='00000000-0000-0000-0000-0000000000F1' and start_at<=now() and end_at>=now() limit 10;"
echo "✅ discounts SQL gates executed"
