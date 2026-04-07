#!/usr/bin/env bash
set -euo pipefail
: "${SUPABASE_DB_URL:?}"

before=$(psql -At "$SUPABASE_DB_URL" -c "select coalesce(sum(total_cents_30d),0) from v_roi_kpis_30d")
psql "$SUPABASE_DB_URL" -c "insert into ai_roi_events(org_id,event_type,amount_cents,is_backfill,created_at) values (gen_random_uuid(),'fuel_savings',12345,true,now())"
after=$(psql -At "$SUPABASE_DB_URL" -c "select coalesce(sum(total_cents_30d),0) from v_roi_kpis_30d")
[ "$before" = "$after" ] || { echo '❌ KPI changed by backfill'; exit 3; }
echo '✅ KPI excludes backfill'
