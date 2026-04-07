#!/usr/bin/env bash
set -euo pipefail
: "${SUPABASE_DB_URL:?}"
min=$(psql -At "$SUPABASE_DB_URL" -c "select coalesce(min(pct_with_required),100) from v_ai_factor_coverage_7d")
awk -v m="$min" 'BEGIN{
  if (m+0 < 98) { print "❌ factor coverage < 98% (" m "%)"; exit 2 }
  else { print "✅ factor coverage " m "%" }
}'
