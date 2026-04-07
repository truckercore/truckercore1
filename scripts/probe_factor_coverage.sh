#!/usr/bin/env bash
set -euo pipefail
: "${SUPABASE_DB_URL:?}"

# Fail if any model/version has <98% coverage of required factors over 7 days
val=$(psql -At "$SUPABASE_DB_URL" -c "select coalesce(min(pct_with_required),100) from v_ai_factor_coverage_7d")
awk -v v="$val" 'BEGIN{ if (v+0 < 98) { print "❌ factor coverage <98% (" v "%)"; exit 2 } else { print "✅ factor coverage " v "%" } }'
